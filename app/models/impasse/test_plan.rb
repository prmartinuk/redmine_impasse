module Impasse
  class TestPlan < ActiveRecord::Base
    unloadable
    self.table_name = "impasse_test_plans"
    self.include_root_in_json = false

    has_many :test_plan_cases
    has_many :test_cases, :through => :test_plan_cases
    has_many :executions

    belongs_to :query, :foreign_key => "query_id"
    belongs_to :version

    validates_presence_of :name
    validates_presence_of :version
    validates_presence_of :query
    validates_length_of :name, :maximum => 100

    acts_as_customizable

    def requirements_issues
      issues = []
      unless self.query.nil?
        issues = self.query.issues.to_a
      end
      self.test_cases.each do |test_case|
        test_case.requirement_issues.each do |tc_issues|
          issues.append(tc_issues.issue)
        end
      end  
      issues.uniq.flatten.compact
    end

    def setting
      @setting = Impasse::Setting.find_by_project_id(version.project.id)
    end

    def self.find_test_cases(version_id)
      TestPlan.where(:version_id => version_id.to_i).map(&:test_cases).flatten.uniq
    end

    def self.find_test_case_name(test_case_id)
      begin
        Node.find(test_case_id).name
      rescue ActiveRecord::RecordNotFound
        nil
      end
    end

    def self.find_version_name(version_id)
      begin
        Version.find(version_id).name
      rescue ActiveRecord::RecordNotFound
        nil
      end
    end

    def self.find_all_by_version(project, show_closed = false)
      versions = Impasse::Node.find_version(project, show_closed)
      test_plans_by_version = {}
      versions.each do |version|
        test_plans = Impasse::TestPlan.find(:all, :conditions => ["version_id=?", version.id])
        test_plans_by_version[version] = test_plans
      end
      [test_plans_by_version, versions]
    end

    def self.get_statistics_for_plan(version, plan)
      executions = Impasse::Execution.joins(:test_plan)
                     .where("#{Impasse::TestPlan.table_name}.version_id = ?", version.id)
                     .where(:test_plan_id => plan.id)
      total = executions.count
      ok = executions.reject{|execution| execution if execution.status.to_i != 1}.count
      nog = executions.reject{|execution| execution if execution.status.to_i != 2}.count
      block = executions.reject{|execution| execution if execution.status.to_i != 3}.count
      nok = nog+block
      undone = total-nok-ok
      [total,ok,nog,block,undone]
    end
    
    def self.get_statistics(version)
      executions = Impasse::Execution.joins(:test_plan)
                     .where("#{Impasse::TestPlan.table_name}.version_id = ?", version.id)
      total = executions.count
      ok = executions.reject{|execution| execution if execution.status.to_i != 1}.count
      nog = executions.reject{|execution| execution if execution.status.to_i != 2}.count
      block = executions.reject{|execution| execution if execution.status.to_i != 3}.count
      nok = nog+block
      undone = total-nok-ok
      [total,ok,nog,block,undone]
    end

    def self.find_test_coverage(version_id, test_case_id)
      executions = Impasse::Execution.joins(:test_plan).joins(:test_case)
                     .where(:test_case_id => test_case_id)
                     .where("#{Impasse::TestPlan.table_name}.version_id = ?", version_id)
                     .where("#{Impasse::TestCase.table_name}.active = ?", true)
      total = executions.count
      ok = executions.reject{|execution| execution if execution.status.to_i != 1}.count
      nog = executions.reject{|execution| execution if execution.status.to_i != 2}.count
      block = executions.reject{|execution| execution if execution.status.to_i != 3}.count
      nok = nog+block
      undone = total-nok-ok
      [total,ok,nog,block,undone]
    end

    def self.find_test_coverage_stats(version_id)
      executions = Impasse::Execution.joins(:test_plan).joins(:test_case)
                     .where("#{Impasse::TestPlan.table_name}.version_id = ?", version_id)
                     .where("#{Impasse::TestCase.table_name}.active = ?", true)
      total = executions.count
      ok = executions.reject{|execution| execution if execution.status.to_i != 1}.count
      nog = executions.reject{|execution| execution if execution.status.to_i != 2}.count
      block = executions.reject{|execution| execution if execution.status.to_i != 3}.count
      nok = nog+block
      undone = total-nok-ok
      [total,ok,nog,block,undone]
    end

    def self.find_test_coverage_case(test_case_id)
      Impasse::Execution.joins(:test_case)
                     .where("#{Impasse::TestCase.table_name}.active = ?", true)
                     .where(:test_case_id => test_case_id).order("test_plan_id DESC")
    end

    def self.find_case_coverage(test_case_id, test_plan_id)
      executions = Impasse::Execution.where(:test_case_id => test_case_id, :test_plan_id => test_plan_id)
                     .joins(:test_case)
                     .where("#{Impasse::TestCase.table_name}.active = ?", true)
      total = executions.count
      ok = executions.reject{|execution| execution if execution.status.to_i != 1}.count
      nog = executions.reject{|execution| execution if execution.status.to_i != 2}.count
      block = executions.reject{|execution| execution if execution.status.to_i != 3}.count
      nok = nog+block
      undone = total-nok-ok
      [total,ok,nog,block,undone]
    end

  end
end
