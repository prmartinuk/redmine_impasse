class ImpasseTestSuiteController < ApplicationController
  
  before_filter :find_project
  before_filter :get_settings

  helper :custom_fields
  include CustomFieldsHelper

  def new
    @node = Impasse::Node.new(params[:node])
    @test_suite = Impasse::TestSuite.new(params[:test_suite])
    @node.node_type_id = 2
  end

  def show
    @node = Impasse::Node.find(params[:id])
    @test_suite = @node.test_suite
    render :layout => false
  end

  def create
    @node = Impasse::Node.new(params[:node])
    @test_suite = Impasse::TestSuite.new(params[:test_suite])
    @node.node_type_id = 2
    if @node.parent_id.nil?
      parent = Impasse::Node.find_by_name_and_node_type_id(@project.identifier, 1)
      @node.parent_id = parent.id
    end
    @node.node_order = Impasse::Node.where(:parent_id => @node.parent_id).map(&:node_order).max.to_i + 1
    begin
      success = false
      ActiveRecord::Base.transaction do
        success = @node.save!
        Impasse::Node.update_order_lft(@node)
        success = @node.save_keywords!(params[:node_keywords] || "") && success
        @test_suite.id = @node.id
        success = @test_suite.save! && success
      end
      if success
        flash[:notice] = l(:notice_successful_create)
        redirect_to :controller => :impasse_test_case, :action => :index, :anchor => "testcase-#{@node.id}"
      end
    rescue ActiveRecord::ActiveRecordError => e
      errors = []
      errors.concat(@node.errors.full_messages).concat(@test_suite.errors.full_messages)
      flash.now[:error] = errors.join("<br>")
      render :new
    end
  end

  def edit
    @node = Impasse::Node.find(params[:id])
    @test_suite = @node.test_suite
  end

  def update
    @node = Impasse::Node.find(params[:id])
    @test_suite = @node.test_suite
    @node.attributes = params[:node]
    @test_suite.attributes = params[:test_suite]
    begin
      success = false
      ActiveRecord::Base.transaction do
        success = save_node(@node)
        Impasse::Node.update_order_lft(@node)
        success = @node.save_keywords!(params[:node_keywords] || "") && success
      end
      if success
        flash[:notice] = l(:notice_successful_update)
        redirect_to :controller => :impasse_test_case, :action => :index, :anchor => "testcase-#{@node.id}"
      end
    rescue ActiveRecord::ActiveRecordError=> e
      errors = []
      errors.concat(@node.errors.full_messages).concat(@test_suite.errors.full_messages)
      flash.now[:error] = errors.join("<br>")
      render :edit
    end
  end

  private
  def save_node(node)
    save_node = node.save!
    update_order = node.update_siblings_order!
    return save_node && update_order
  end

  def get_settings
    @setting = Impasse::Setting.find_by_project_id(@project) || Impasse::Setting.create(:project_id => @project.id)
  end

  def find_project
    begin
      @project = Project.find(params[:project_id])
      @project_node = Impasse::Node.find(:first, :conditions=>["name=? and node_type_id=?", @project.identifier, 1])
      if @project_node.nil?
        @project_node = Impasse::Node.new(:name=>@project.identifier, :node_type_id=>1, :node_order=>1)
        @project_node.save
      end
    rescue ActiveRecord::RecordNotFound
      render_404
    end
  end

end