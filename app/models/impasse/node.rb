module Impasse
  class Node < ActiveRecord::Base
    unloadable
    self.table_name = "impasse_nodes"
    self.include_root_in_json = false

    acts_as_tree order: "id"
    acts_as_nested_set :order => "parent_id, node_order", :dependent => :destroy
    has_many   :node_keywords, :class_name => "Impasse::NodeKeyword", :dependent => :delete_all
    has_many   :keywords, :through => :node_keywords
    has_one :test_case, :class_name => "Impasse::TestCase", :foreign_key => "id"
    has_one :test_suite, :class_name => "Impasse::TestSuite", :foreign_key => "id"

    validates_presence_of :name

    def hierarchy
      parents = self.self_and_ancestors || []
      descendants = self.descendants || []
      node_hierarchy = parents | descendants
    end

    def self.find_version(project, show_closed = false)
      versions = project.shared_versions || []
      versions = versions.uniq.sort
      unless show_closed
        versions.reject! {|version| version.closed? || version.completed? }
      end
      versions
    end

    def find_with_children
      self.descendants
    end

    def find_with_children_test_case
      self.descendants.where(:node_type_id => 3)
    end

    def find_with_children_test_suite
      self.descendants.where(:node_type_id => 2)
    end

    def is_test_case?
      self.node_type_id == 3
    end

    def is_test_suite?
      self.node_type_id == 2
    end

    def is_test_project?
      self.node_type_id == 1
    end


    def active?
      if self.is_test_case?
        return self.test_case.active
      else
        return false
      end
    end

    def planned?
      if self.is_test_case?
        if self.test_case.test_plans.any?
          return true
        else
          return false
        end
      else
        return false
      end
    end

    def find_children(test_plan_id, filters={})
      ret_nodes = []
      nodes = self.find_with_children_test_case
      if filters.include? "query"
        filters["query"].split.each do |word|
          nodes = nodes.where("LOWER(name) LIKE '%#{word.mb_chars.downcase.to_s}%'")
        end
      end
      if filters.include? "keywords"
        keywords = filters["keywords"].split(/\s*,\s*/).delete_if{|k| k == ""}.uniq
        nodes = nodes.joins(:keywords).where('"impasse_keywords".keyword IN (?)', keywords)        
      end
      nodes.each do |node|
        add_to_list = true
        if node.is_test_case?
          test_case = TestCase.find(node.id)
          unless filters.include? "inactive"
            unless test_case.active?
              add_to_list = false
            end
          end
          unless test_plan_id.nil?
            if not test_case.test_plans.map(&:id).include? test_plan_id.to_i
              add_to_list = false
            end
          end
        end
        if add_to_list
          ret_nodes << node
        end
      end
      test_suites = self.find_with_children_test_suite
      if ret_nodes.count > 0
        nodes_group_by_parent = ret_nodes.group_by(&:parent_id)
        ret_nodes += test_suites
        ret_nodes.uniq.sort_by(&:lft)
      else
        if self.parent_id.nil?
          test_suites.uniq.sort_by(&:lft)
        else
          return []
        end
      end
    end

    def update_siblings_order!
      siblings = Node.find(:all,
                           :conditions=>["parent_id=? and id != ?", self.parent_id, self.id],
                           :order=>:node_order)
      if self.node_order < siblings.size
        siblings.insert(self.node_order, self)
      else
        siblings << self
      end
      
      siblings.each_with_index do |sibling, i|
        next if sibling.id == self.id or sibling.node_order == i
        sibling.node_order = i
        sibling.save!
      end
      self.update_order_lft
    end

    def update_order_lft
      unless self.root.valid?
        Node.rebuild!
      end
      self.root.children.sort_by(&:node_order).each do |sibling|
        unless sibling.prev.nil?
          sibling.move_to_right_of(sibling.prev)
        else
          sibling.move_to_child_of(sibling.parent)
        end
        if sibling.children.any?
          Node.update_order_level_children(sibling.children.sort_by(&:node_order), sibling)
        end
      end
    end

    def self.update_order_level_children(childrens, parent)
      childrens.each do |sibling|
        unless sibling.prev.nil?
          sibling.move_to_right_of(sibling.prev)
        else
          sibling.move_to_child_of(parent)
        end
        if sibling.children.any?
          Node.update_order_level_children(sibling.children.sort_by(&:node_order), sibling)
        end
      end
    end

    def next(count=0)
      begin
        Node.where("node_order > ? and parent_id = ?", self.node_order.to_i + count.to_i, self.parent.id).order('node_order ASC').first
      rescue
        nil
      end
    end

    def prev(count=0)
      begin
        Node.where("node_order < ? and parent_id = ?", self.node_order.to_i + count.to_i, self.parent.id).order('node_order DESC').first
      rescue
        nil
      end
    end

    def save_keywords!(keywords)
      root_node = self.root
      project = Project.find_by_identifier(root_node.name)
      project_keywords = Impasse::Keyword.find_all_by_project_id(project)
      words = keywords.split(/\s*,\s*/)
      words.delete_if {|word| word =~ /^\s*$/}.uniq!

      node_keywords = self.node_keywords
      keeps = []
      words.each do |word|
        keyword = project_keywords.detect {|k| k.keyword == word}
        if keyword
          node_keyword = node_keywords.detect {|nk| nk.keyword_id == keyword.id}
          if node_keyword
            keeps << node_keyword.id
          else
            new_node_keyword = Impasse::NodeKeyword.create(:keyword_id => keyword.id, :node_id => self.id)
            keeps << new_node_keyword.id
          end
        else
          new_keyword = Impasse::Keyword.create(:keyword => word, :project_id => project.id)
          new_node_keyword = Impasse::NodeKeyword.create(:keyword_id => new_keyword.id, :node_id => self.id)
          keeps << new_node_keyword.id
        end
      end

      node_keywords.each do |node_keyword|
        node_keyword.destroy unless keeps.include? node_keyword.id
      end
    end

  end
end
