module Impasse
  class Statistics < ActiveRecord::Base
    unloadable
    self.table_name = 'impasse_test_plans'
    self.include_root_in_json = false

    def self.summary_default(test_plan_id)
      executions = Impasse::Execution.scoped
      executions = executions.where(:test_plan_id => test_plan_id)
      test_plan = Impasse::TestPlan.find(test_plan_id)
      test_plan_cases = TestPlanCase.where(:test_plan_id => test_plan_id).map(&:test_case_id)
      executions = executions.where("test_case_id IN (?)", test_plan_cases)
      total = test_plan_cases.count
      ok = executions.reject{|execution| execution if execution.status.to_i != 1}.count
      nog = executions.reject{|execution| execution if execution.status.to_i != 2}.count
      block = executions.reject{|execution| execution if execution.status.to_i != 3}.count
      executed = executions.count
      exec_issues = executions.map(&:execution_bugs).flatten.map(&:issue).uniq
      bugs = exec_issues.count
      closed_bugs = exec_issues.reject{|issue| issue if not issue.closed? }.count
      return [test_plan.name, total, executed, bugs, closed_bugs, ok, nog, block]
    end

    def self.summary_members(test_plan_id)
      ret = []
      user_executions = Impasse::Execution.where(:test_plan_id => test_plan_id).group_by(&:tester)
      user_executions.each do |user, executions|
        total = executions.count
        ok = executions.reject{|execution| execution if execution.status.to_i != 1}.count
        nog = executions.reject{|execution| execution if execution.status.to_i != 2}.count
        block = executions.reject{|execution| execution if execution.status.to_i != 3}.count
        exec_issues = executions.map(&:execution_bugs).flatten.map(&:issue).uniq
        bugs = exec_issues.count
        closed_bugs = exec_issues.reject{|issue| issue if not issue.closed? }.count
        ret.append({ :user => user, :total => total, :ok => ok, :nog => nog, :block => block, :bugs => bugs, :closed_bugs => closed_bugs })
      end
      return ret
    end

    def self.summary_daily(test_plan_id)
      sql = <<-END_OF_SQL
SELECT CASE WHEN execution_ts IS NULL OR exe.status='0' THEN NULL ELSE cast(execution_ts as date) END AS execution_date,
  SUM(CASE exe.status WHEN '1' THEN 1 ELSE 0 END) AS ok,
  SUM(CASE exe.status WHEN '2' THEN 1 ELSE 0 END) AS ng,
  SUM(CASE exe.status WHEN '3' THEN 1 ELSE 0 END) AS block,
  SUM(1) AS total
FROM impasse_test_cases AS tc
INNER JOIN impasse_test_plan_cases AS tpc
  ON tpc.test_case_id = tc.id
LEFT OUTER JOIN impasse_executions AS exe
  ON exe.test_plan_case_id = tpc.id
WHERE tpc.test_plan_id=?
GROUP BY execution_date
      END_OF_SQL
      statistics = find_by_sql([sql, test_plan_id])

      expected_sql = <<-END_OF_SQL
      SELECT  expected_date, count(*) AS total
      FROM impasse_test_cases AS tc
      INNER JOIN impasse_test_plan_cases AS tpc
        ON tpc.test_case_id = tc.id
      LEFT OUTER JOIN impasse_executions AS exe
        ON exe.test_plan_case_id = tpc.id
      WHERE tpc.test_plan_id = :test_plan_id
      GROUP BY expected_date
      END_OF_SQL
      expected_statistics = find_by_sql([expected_sql, {:test_plan_id => test_plan_id}])

      res = [[], [], []]
      sum = { :remain => 0, :expected => 0, :bug => 0}

      start_date = end_date = nil

      statistics.each{|st|
        if st.execution_date
          start_date = st.execution_date.to_date if start_date.nil? or st.execution_date.to_date < start_date
          end_date   = st.execution_date.to_date if end_date.nil? or st.execution_date.to_date > end_date
        end
        sum[:remain] += st.total.to_i
      }
      expected_statistics.each{|st|
        if st.expected_date
          start_date = st.expected_date.to_date if start_date.nil? or st.expected_date.to_date < start_date
          end_date   = st.expected_date.to_date if end_date.nil? or st.expected_date.to_date > end_date
        end
        sum[:expected] += st.total.to_i
      }
      start_date = Date.today if start_date.nil?
      end_date   = Date.today if end_date.nil?
      (start_date-1..end_date).each{|d|
        st = statistics.detect{|st| st.execution_date and st.execution_date.to_date == d}
        if st
          sum[:bug] += st.ng.to_i
          sum[:remain] -= st.total.to_i
        end
        exp_st = expected_statistics.detect{|st| st.expected_date and st.expected_date.to_date == d}
        if exp_st
          sum[:expected] -= exp_st.total.to_i
        end

        res[0] << [ d.to_date, sum[:expected] ]
        res[1] << [ d.to_date, sum[:remain]]
        res[2] << [ d.to_date, sum[:bug] ]
      }
      res
    end
  end
end
