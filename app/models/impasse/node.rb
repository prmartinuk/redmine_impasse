module Impasse

  class Node < ActiveRecord::Base
    unloadable
    
    if Rails::VERSION::MAJOR >= 3 
      self.table_name = 'impasse_nodes'
    else
      set_table_name "impasse_nodes"
    end
    
    self.include_root_in_json = false

    belongs_to :parent, :class_name=>'Node', :foreign_key=> :parent_id
    has_many   :children, :class_name=> 'Node', :foreign_key=> :parent_id
    has_many   :node_keywords, :class_name => "Impasse::NodeKeyword", :dependent => :delete_all
    has_many   :keywords, :through => :node_keywords

    validates_presence_of :name

    @@concatinated_path =
      case configurations[Rails.env]['adapter']
        when /mysql/
          "CONCAT(:path, head.id, '.')"
        when /sqlserver/
          ":path + head.id + '.'"
        else
          ":path || head.id || '.'"
        end
  
    @@length_for_sql =
      case configurations[Rails.env]['adapter']
        when /mysql/
          "LENGTH"
        when /sqlserver/
          "LEN"
        else
          "LENGTH"
        end

    @@substr_for_sql =
      case configurations[Rails.env]['adapter']
        when /mysql/
          "SUBSTR"
        when /sqlserver/
          "SUBSTRING"
        else
          "SUBSTR"
        end

    @@exists_for_sql_initial =
      case configurations[Rails.env]['adapter']
        when /mysql/
          "EXISTS("
        when /sqlserver/
          "CASE WHEN EXISTS("
        else
          "EXISTS(" # not yet tested
        end

    @@exists_for_sql_final =
      case configurations[Rails.env]['adapter']
        when /mysql/
          ")"
        when /sqlserver/
          ") THEN 1 ELSE 0 END "
        else
          ")" # not yet tested
        end

    if Rails::VERSION::MAJOR < 3 or (Rails::VERSION::MAJOR == 3 and Rails::VERSION::MINOR < 1)
      def dup
        clone
      end
    end

    def self.find_with_children(id)
      node = self.find(id)
      
      sql =  " SELECT distinct parent.*, " + @@length_for_sql + "(parent.path) - " + @@length_for_sql + "(REPLACE(parent.path,'.','')) - 2 AS level"
      sql << " FROM impasse_nodes AS parent"
      sql << " JOIN impasse_nodes AS child"
      sql << "    ON parent.path = " + @@substr_for_sql + "(child.path, 1, " + @@length_for_sql + "(parent.path))"
      sql << " WHERE parent.path like ?"
      sql << " ORDER BY level, node_order"
      
      self.find_by_sql([sql, "#{node.path}%"])
    end

    def is_test_case?
      self.node_type_id == 3
    end

    def is_test_suite?
      self.node_type_id == 2
    end

    def active?    
      case configurations[Rails.env]['adapter']
        when /sqlserver/
          (!attributes['active']) or (attributes['active'].blank? ? false : (attributes['active'] == '1')) or (attributes['active'].is_a? TrueClass) or (attributes['active'] == 't')
        else
          !attributes['active'] or attributes['active'].to_i  == 1 or attributes['active'].is_a? TrueClass or attributes['active'] == 't'
        end    
    end

    def planned?
      attributes['planned'].to_i == 1 or attributes['planned'].is_a? TrueClass or attributes['planned'] == 't'
    end

    def self.find_children(node_id, test_plan_id=nil, filters=nil, limit=300)
      sql = <<-'END_OF_SQL'
      SELECT node.*, tc.active
      FROM (
        SELECT distinct parent.*, <%= @@length_for_sql %>(parent.path) - <%= @@length_for_sql %>(REPLACE(parent.path,'.','')) level
          FROM impasse_nodes AS parent
        JOIN impasse_nodes AS child
          ON parent.path = <%= @@substr_for_sql %>(child.path, 1, <%= @@length_for_sql %>(parent.path))
        <%- if conditions.include? :test_plan_id -%>
        LEFT JOIN impasse_test_cases AS tc
          ON tc.id=child.id
        LEFT JOIN impasse_test_plan_cases AS tpts
          ON tc.id=tpts.test_case_id
        <%- end -%>
        WHERE 1=1
        <%- if conditions.include? :test_plan_id -%>
          AND tpts.test_plan_id=:test_plan_id
        <%- end -%>
        <%- if conditions.include? :path -%>
          AND parent.path LIKE :path
        <%- end -%>
        <%- if conditions.include? :level -%>
          AND <%= @@length_for_sql %>(parent.path) - <%= @@length_for_sql %>(REPLACE(parent.path,'.','')) <= :level
        <%- end -%>
        <%- if conditions.include? :filters_query or conditions.include? :filters_keywords -%>
        AND
          <%- if conditions.include? :filters_query -%>
             child.name like :filters_query
             <%- if conditions.include? :filters_keywords -%>AND <%- end -%>
          <%- end -%>
          <%- if conditions.include? :filters_keywords -%>
            <%= @@exists_for_sql_initial %>
              SELECT 1 FROM impasse_node_keywords AS nk
                JOIN impasse_keywords AS k ON k.id = nk.keyword_id
              WHERE nk.node_id = child.id
                AND k.keyword in (:filters_keywords)
            <%= @@exists_for_sql_final %>  
          <%- end -%>
        <%- end -%>
      ) AS node
      LEFT OUTER JOIN impasse_test_cases AS tc
        ON node.id = tc.id
      WHERE 1=1
      <%- unless conditions.include? :filters_inactive -%>
        AND tc.active = :true OR tc.active IS NULL
        ORDER BY level, node_order
      <%- end -%>
      END_OF_SQL

      conditions = { :true => true }
    
      unless test_plan_id.nil?
        conditions[:test_plan_id] = test_plan_id
      end

      unless node_id.to_i == -1
        node = find(node_id)
        child_counts = self.count(:conditions => [ "path like ?", "#{node.path}_%"])
        if child_counts > limit
          conditions[:level] = node.path.count('.') + 1
        end
        conditions[:path] = "#{node.path}_%"
      end
    
      if filters and filters[:query]
        conditions[:filters_query] = "%#{filters[:query]}%"
      end

      if filters and filters[:keywords]
        keywords = filters[:keywords].split(/\s*,\s*/).delete_if{|k| k == ""}.uniq
        conditions[:filters_keywords] = keywords
      end

      if filters and filters[:inactive]
        conditions[:filters_inactive] = true
      end

      find_by_sql([ERB.new(sql, nil, '-').result(binding), conditions])
    end

    def self.find_planned(node_id, test_plan_id=nil, filters={}, limit=300)
      sql = <<-'END_OF_SQL'
    SELECT T.*, <%= @@length_for_sql %>(T.path) - <%= @@length_for_sql %>(REPLACE(T.path,'.','')) level, 
      E.expected_date, E.status, users.firstname, users.lastname
      FROM (
        SELECT distinct parent.*, tpc.test_plan_id
          FROM impasse_nodes AS parent
          JOIN impasse_nodes AS child
            ON parent.path = <%= @@substr_for_sql %>(child.path, 1, <%= @@length_for_sql %>(parent.path))
     LEFT JOIN impasse_test_cases AS tc
            ON child.id = tc.id
     LEFT JOIN impasse_test_plan_cases AS tpc
            ON tc.id=tpc.test_case_id
     LEFT JOIN impasse_executions AS execut
            ON tpc.id = execut.test_plan_case_id
         WHERE tpc.test_plan_id=:test_plan_id
     <%- if conditions.include? :level -%>
           AND <%= @@length_for_sql %>(parent.path) - <%= @@length_for_sql %>(REPLACE(parent.path,'.','')) <= :level
     <%- end -%>
     <%- if conditions.include? :path -%>
           AND parent.path LIKE :path
     <%- end -%>
     <%- if [:user_id, :execution_status, :expected_date].any? {|key| conditions.include? key} -%>
       <%- if conditions.include? :user_id -%>
           AND tester_id = :user_id
       <%- end -%>
       <%- if conditions.include? :execution_status -%>
           AND (execut.status IN (:execution_status) <%- if conditions[:execution_status].include? "0" %>OR execut.status IS NULL<% end %> )
       <%- end -%>
       <%- if conditions.include? :expected_date -%>
           AND execut.expected_date <%= conditions[:expected_date_op] %> :expected_date
       <%- end -%>
     <%- end -%>
      ) AS T
LEFT JOIN impasse_test_plan_cases
       ON T.id = impasse_test_plan_cases.test_case_id AND
          T.test_plan_id = impasse_test_plan_cases.test_plan_id
LEFT JOIN impasse_executions AS E
       ON E.test_plan_case_id = impasse_test_plan_cases.id
LEFT OUTER JOIN users
       ON users.id = tester_id
ORDER BY level, T.node_order
      END_OF_SQL

      conditions = { :test_plan_id => test_plan_id }

      unless node_id.to_i == -1
        node = self.find(node_id)
        child_counts = self.count(:conditions => [ "path like ?", "#{node.path}_%"])
        if child_counts > limit
          conditions[:level] = node.path.count('.') + 1
        end
        conditions[:path] = "#{node.path}_%"
      else
        child_counts = Impasse::TestPlanCase.count(:conditions => [ "test_plan_id=?", test_plan_id])
        if child_counts > limit
          conditions[:level] = 3
        end
      end

      if filters[:myself]
        conditions[:user_id] = User.current.id
      end

      if filters[:execution_status]
        conditions[:execution_status] = []
        if filters[:execution_status].is_a? Array
          filters[:execution_status].each {|param|
            conditions[:execution_status] << param.to_s
          }
        else
          conditions[:execution_status] << filters[:execution_status].to_s
        end
      end

      if filters[:expected_date]
        conditions[:expected_date] = filters[:expected_date]
        conditions[:expected_date_op] = filters[:expected_date_op] || '='
      end

      nodes = self.find_by_sql([ERB.new(sql, nil, '-').result(binding), conditions])
      if nodes.size > 0 and nodes[0].node_type_id == 1
        test_plan = Impasse::TestPlan.find(test_plan_id)
        nodes[0].name = test_plan.name
      end
      nodes
    end

    def all_decendant_cases
      sql = <<-'END_OF_SQL'
      SELECT distinct parent.*
        FROM impasse_nodes AS parent
      JOIN impasse_nodes AS child
        ON parent.path = <%= @@substr_for_sql %>(child.path, 1, <%= @@length_for_sql %>(parent.path))
      LEFT JOIN impasse_test_cases AS tc
        ON child.id = tc.id
      WHERE parent.path LIKE :path
        AND parent.node_type_id=3
      END_OF_SQL
      conditions = {:path => "#{self.path}%"}
      Node.find_by_sql([ERB.new(sql).result(binding), conditions])
    end

    def all_decendant_cases_with_plan
      sql = <<-'END_OF_SQL'
      SELECT distinct parent.*, <%= @@length_for_sql %>(parent.path) - <%= @@length_for_sql %>(REPLACE(parent.path,'.','')) level,
             tc.active, 
             <%= @@exists_for_sql_initial %>
                SELECT * FROM impasse_test_plan_cases AS tpc WHERE tpc.test_case_id = parent.id
             <%= @@exists_for_sql_final %> 
             AS planned
        FROM impasse_nodes AS parent
      JOIN impasse_nodes AS child
        ON parent.path = <%= @@substr_for_sql %>(child.path, 1, <%= @@length_for_sql %>(parent.path))
      LEFT JOIN impasse_test_cases AS tc
        ON child.id = tc.id
      WHERE parent.path LIKE :path
      ORDER BY level DESC
      END_OF_SQL
      conditions = {:path => "#{self.path}%"}
      Node.find_by_sql([ERB.new(sql).result(binding), conditions])
    end

    def save!
      if new_record?
        # dummy path
        write_attribute(:path, ".")
        super
      end

      recalculate_path
      super
    end

    def save
      if new_record?
        # dummy path
        write_attribute(:path, ".")
        return false unless super
      end

      recalculate_path
      super
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
      
      change_nodes = []
      siblings.each_with_index do |sibling, i|
        next if sibling.id == self.id or sibling.node_order == i
        sibling.node_order = i
        change_nodes << sibling
      end

      change_nodes.each {|node| node.save! }
    end
 
    def update_child_nodes_path(old_path)
      sql = <<-'END_OF_SQL'
      UPDATE impasse_nodes
      SET path = replace(path, '#{old_path}', '#{self.path}')
      WHERE path like '#{old_path}_%'
      END_OF_SQL
      
      connection.update(sql)
    end

    def save_keywords!(keywords = "")
      root_node = Impasse::Node.find(self.path.sub(/^\.(\d+)\.[\d\.]*$/, '\1').to_i)
      project = Project.find(root_node.name)
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

    private
    def recalculate_path
      if parent.nil?
        write_attribute(:path, ".#{read_attribute(:id)}.")
      else
        write_attribute(:path, "#{parent.path}#{read_attribute(:id)}.")
      end
    end
  end
end
