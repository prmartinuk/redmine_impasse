#TestCases
match 'projects/:project_id/impasse/test_case', :to => 'impasse_test_case#index', :via => 'GET'
match 'projects/:project_id/impasse/test_case/new', :to => 'impasse_test_case#new', :via => 'GET'
match 'projects/:project_id/impasse/test_case/list', :to => 'impasse_test_case#list', :via => 'GET'
match 'projects/:project_id/impasse/test_case/show(/:id)', :to => 'impasse_test_case#show', :via => 'GET'
match 'projects/:project_id/impasse/test_case/edit(/:id)', :to => 'impasse_test_case#edit', :via => 'GET'
match 'projects/:project_id/impasse/test_case/create', :to => 'impasse_test_case#create', :via => 'POST'
match 'projects/:project_id/impasse/test_case/update(/:id)', :to => 'impasse_test_case#update', :via => 'PUT'
match 'projects/:project_id/impasse/test_case/destroy(/:id)', :to => 'impasse_test_case#destroy', :via => 'DELETE'
match 'projects/:project_id/impasse/test_case/keywords', :to => 'impasse_test_case#keywords', :via => 'GET'
match 'projects/:project_id/impasse/test_case/copy', :to => 'impasse_test_case#copy', :via => 'POST'
match 'projects/:project_id/impasse/test_case/move', :to => 'impasse_test_case#move', :via => 'POST'
match 'projects/:project_id/impasse/test_case/rebuild_tree', :to => 'impasse_test_case#rebuild_tree', :via => 'POST'
#TestSuites
match 'projects/:project_id/impasse/test_suite/new', :to => 'impasse_test_suite#new', :via => 'GET'
match 'projects/:project_id/impasse/test_suite/show(/:id)', :to => 'impasse_test_suite#show', :via => 'GET'
match 'projects/:project_id/impasse/test_suite/edit(/:id)', :to => 'impasse_test_suite#edit', :via => 'GET'
match 'projects/:project_id/impasse/test_suite/create', :to => 'impasse_test_suite#create', :via => 'POST'
match 'projects/:project_id/impasse/test_suite/update(/:id)', :to => 'impasse_test_suite#update', :via => 'PUT'
#TestPlans
match 'projects/:project_id/impasse/test_plans', :to => 'impasse_test_plans#index', :via => 'GET'
match 'projects/:project_id/impasse/test_plans/new', :to => 'impasse_test_plans#new', :via => 'GET'
match 'projects/:project_id/impasse/test_plans/show(/:id)', :to => 'impasse_test_plans#show', :via => 'GET'
match 'projects/:project_id/impasse/test_plans/edit(/:id)', :to => 'impasse_test_plans#edit', :via => 'GET'
match 'projects/:project_id/impasse/test_plans/create', :to => 'impasse_test_plans#create', :via => 'POST'
match 'projects/:project_id/impasse/test_plans/update(/:id)', :to => 'impasse_test_plans#update', :via => 'PUT'
match 'projects/:project_id/impasse/test_plans/destroy(/:id)', :to => 'impasse_test_plans#destroy', :via => 'DELETE'
match 'projects/:project_id/impasse/test_plans/add_test_case(/:id)', :to => 'impasse_test_plans#add_test_case', :via => 'POST'
match 'projects/:project_id/impasse/test_plans/copy(/:id)', :to => 'impasse_test_plans#copy', :via => ['POST', 'PUT']
match 'projects/:project_id/impasse/test_plans/tc_assign(/:id)', :to => 'impasse_test_plans#tc_assign', :via => 'GET'
match 'projects/:project_id/impasse/test_plans/user_assign(/:id)', :to => 'impasse_test_plans#user_assign', :via => 'GET'
match 'projects/:project_id/impasse/test_plans/statistics(/:id)', :to => 'impasse_test_plans#statistics', :via => 'GET'
match 'projects/:project_id/impasse/test_plans/remove_test_case(/:id)', :to => 'impasse_test_plans#remove_test_case', :via => ['POST', 'DELETE']
match 'projects/:project_id/impasse/test_plans/autocomplete', :to => 'impasse_test_plans#autocomplete', :via => 'GET'
match 'projects/:project_id/impasse/test_plans/coverage(/:id)', :to => 'impasse_test_plans#coverage', :via => 'GET'
match 'projects/:project_id/impasse/test_plans/coverage_case(/:id)', :to => 'impasse_test_plans#coverage_case', :via => 'GET'
#Executions
match 'projects/:project_id/impasse/executions', :to => 'impasse_executions#index', :via => 'GET'
match 'projects/:project_id/impasse/executions/edit(/:id)', :to => 'impasse_executions#edit', :via => 'GET'
match 'projects/:project_id/impasse/executions/put(/:id)', :to => 'impasse_executions#put', :via => ['PUT', 'POST']
match 'projects/:project_id/impasse/executions/destroy(/:id)', :to => 'impasse_executions#destroy', :via => ['DELETE', 'POST']
match 'projects/:project_id/impasse/executions/get_planned(/:id)', :to => 'impasse_executions#get_planned', :via => 'GET'
match 'projects/:project_id/impasse/executions/get_executed(/:id)', :to => 'impasse_executions#get_executed', :via => 'GET'
#ExecutionsBug
match 'projects/:project_id/impasse/execution_bugs/create_bug', :to => 'impasse_execution_bugs#create_bug', :via => 'POST'
#Settings
match 'projects/:project_id/impasse/settings', :to => 'impasse_settings#index', :via => 'GET'
match 'projects/:project_id/impasse/settings/edit/:id', :to => 'impasse_settings#edit', :via => 'GET'
match 'projects/:project_id/impasse/settings/update/:id', :to => 'impasse_settings#update', :via => 'PUT'
#RequirmentIssues
match 'projects/:project_id/impasse/requirement_issues', :to => 'impasse_requirement_issues#index', :via => 'GET'
match 'projects/:project_id/impasse/requirement_issues/add_test_case(/:id)', :to => 'impasse_requirement_issues#add_test_case', :via => 'POST'
match 'projects/:project_id/impasse/requirement_issues/remove_test_case(/:id)', :to => 'impasse_requirement_issues#remove_test_case', :via => 'POST'
#CustomFields
match 'impasse/custom_fields', :to => 'impasse_custom_fields#index', :via => 'GET'
match 'impasse/custom_fields/new', :to => 'impasse_custom_fields#new', :via => ['GET', 'POST']
match 'impasse/custom_fields/edit(/:id)', :to => 'impasse_custom_fields#edit', :via => ['GET', 'POST']
match 'impasse/custom_fields/destroy(/:id)', :to => 'impasse_custom_fields#destroy', :via => 'DELETE'
#ExecStepHists
match 'projects/:project_id/impasse/exec_step_hists/(:action(/:id))', :controller => 'impasse_exec_step_hists'
