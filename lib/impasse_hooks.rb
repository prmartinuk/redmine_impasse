module ImpassePlugin
  class Hook < Redmine::Hook::ViewListener

    def view_issues_show_details_bottom(context = {})
      return '' unless context[:issue].project.module_enabled? 'impasse'
      render_execution_bug = false
      execution_bug = Impasse::ExecutionBug.find(:all, :joins => :execution, :conditions => { :bug_id => context[:issue].id })
      if execution_bug.any?
        render_execution_bug = true
      end

      if render_execution_bug
        return context[:controller].send(:render_to_string, {
          :partial => 'impasse_hooks/execution_bugs', :locals => {
            :executions => execution_bug.map(&:execution).uniq,
            :context => context
          }
        })
      end
    end

    def view_issues_show_description_bottom(context = {})
      issue = context[:issue]

      return '' unless issue.project.module_enabled? 'impasse'

      project = context[:project]
      snippet = ''

      requirement = Impasse::RequirementIssue.find_by_issue_id(context[:issue].id)
      return '' if requirement.nil?
      return '' unless requirement.test_cases.where(:active => true).count > 0
      return context[:controller].send(:render_to_string, {
        :partial => 'impasse_hooks/requirement_cases', :locals => {
          :context => context,
          :test_cases => requirement.test_cases.where(:active => true).order(:id)
        }
      })
    end

  end
end
