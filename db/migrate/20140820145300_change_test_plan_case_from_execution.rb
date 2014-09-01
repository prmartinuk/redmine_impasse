class ChangeTestPlanCaseFromExecution < ActiveRecord::Migration
  def self.up
    add_column :impasse_executions, :test_case_id, :integer, :null => false, :default => 0
    add_column :impasse_executions, :test_plan_id, :integer, :null => false, :default => 0
    add_column :impasse_execution_histories, :execution_id, :integer, :null => false, :default => 0

    add_index :impasse_executions, :test_case_id, :name => 'IDX_IMPASSE_EXECUTIONS_TC'
    add_index :impasse_executions, :test_plan_id, :name => 'IDX_IMPASSE_EXECUTIONS_TP'
    add_index :impasse_execution_histories, :execution_id, :name => 'IDX_IMPASSE_EXEC_HIST_TO_EXEC'
    execute "DELETE FROM impasse_executions WHERE test_plan_case_id NOT IN (SELECT id FROM impasse_test_plan_cases)"
    execute "DELETE FROM impasse_execution_histories WHERE test_plan_case_id NOT IN (SELECT id FROM impasse_test_plan_cases)"
    execute "UPDATE impasse_executions SET test_case_id = (SELECT test_case_id FROM impasse_test_plan_cases where impasse_test_plan_cases.id = impasse_executions.test_plan_case_id), test_plan_id = (SELECT test_plan_id FROM impasse_test_plan_cases where impasse_test_plan_cases.id = impasse_executions.test_plan_case_id)"
    execute "UPDATE impasse_execution_histories SET execution_id = (SELECT id FROM impasse_executions WHERE impasse_executions.test_plan_case_id=impasse_execution_histories.test_plan_case_id)"

    remove_column :impasse_executions, :test_plan_case_id
    remove_column :impasse_execution_histories, :test_plan_case_id
  end

  def self.down
    add_column :impasse_executions, :test_plan_case_id, :integer
    add_column :impasse_execution_histories, :test_plan_case_id, :integer

    add_index :impasse_executions, :test_plan_case_id, :name => 'IDX_IMPASSE_EXECUTIONS_01'
    add_index :impasse_execution_histories, :test_plan_case_id, :name => 'IDX_IMPASSE_EXEC_HIST_01'

    execute "UPDATE impasse_executions SET test_plan_case_id = (SELECT id FROM impasse_test_plan_cases where impasse_test_plan_cases.test_plan_id = impasse_executions.test_plan_id and impasse_test_plan_cases.test_case_id = impasse_executions.test_case_id)"
    execute "UPDATE impasse_execution_histories SET test_plan_case_id = (SELECT test_plan_case_id FROM impasse_executions WHERE impasse_executions.id=impasse_execution_histories.execution_id)"

    remove_column :impasse_executions, :test_case_id
    remove_column :impasse_executions, :test_plan_id
    remove_column :impasse_execution_histories, :execution_id
  end
end
