jQuery.noConflict();
jQuery(document).ready(function($) {

  var topPadding_executions_view = 15;
  var offset_executions_view = $("#executions-view").offset();
  $(window).bind('scroll', function() {
    if ($(window).scrollTop() > offset_executions_view.top) {
      $("#executions-view").stop().animate({marginTop: $(window).scrollTop() - offset_executions_view.top + topPadding_executions_view}, 0);
    }
    else {
      $("#executions-view").stop().animate({marginTop: 0}, 0);
    }
  });

  function sobrescrever_show_test_case() {
    $(".list select ").each(function() {
      var step_id = $(this).attr('test_step_id');
      $.get(IMPASSE.url.executionStepHistList + "&test_case_id=" + $(this).attr('test_case_id') + "&test_step_id=" + step_id, {}, function(data) {
        $('#ajax-indicator').hide();
        $("#div-step-hist_" + step_id).html(data);
      });
      $.get(IMPASSE.url.executionStepHistLast + "?test_step_id=" + step_id, {}, function(data) {
        $('#ajax-indicator').hide();
        var status_step = data.status_step;
        $("#status_step_execucao_" + data.test_steps_id).find("option").each(function() {
          if ($(this).val() == data.status_step) {
            $(this).prop("selected", "selected");
          }
        });
      });
    });
  }

  function show_test_case(node_id) {
    $.ajax({
      url : IMPASSE.url.executionsEdit,
      data : {
        "test_plan_case[test_plan_id]" : test_plan_id,
        "test_plan_case[test_case_id]" : node_id
      },
      success : function(html) {
        var winHeight = $(window).height();
        var $executionsView = $("#executions-view");
        $executionsView.css({
          height : '',
          overflow : ''
        }).html(html);
        $("span.label", $executionsView).css({
          cursor : 'pointer'
        }).click(function(e) {
          $(this).prev().attr("checked", "checked");
        });
        if ($executionsView.height() > winHeight) {
          $executionsView.height(winHeight - 1).css('overflow', 'scroll');
        }
        sobrescrever_show_test_case();
      },
      error : ajax_error_handler,
      complete : function() {
        $('#ajax-indicator').hide();
        $("#executions-view").floatmenu();
      }
    });
  }

  var $tree = $("#testplan-tree")
    .jstree({
      "plugins" : ["themes", "json_data", "ui", "crrm", "search", "types", "hotkeys", "cookies"],
      json_data : {
        ajax : {
          url : IMPASSE.url.executionsList,
          data : function(n) {
            var params = {
              prefix : "exec",
              id : n.attr ? n.attr("id").replace("exec_", "") : -1
            };
            if ($("#filters #cb_myself").is(":checked")) {
              params["filters[myself]"] = true;
            }
            params["filters[execution_status]"] = $("#filters :checkbox[name=execution_status]:checked").map(function() {
               return $(this).val();
            }).get();
            $.each(["expected_date", "expected_date_op"], function(i, key) {
              var val = $("#filters :input[name=" + key + "]").val();
              if (val){
                params["filters[" + key + "]"] = val;
              }
            });
            return params;
          },
          complete : function() {
            $('#ajax-indicator').hide();
          }
        }
      },
      cookies : {
          save_opened : true,
          save_selected : false,
          auto_save : true
      },
      types : {
        max_depth : -2,
        max_children : -2,
        valid_children : ["test_project"],
        types : {
          test_case : {
            valid_children : "none",
            icon : {
              image : IMPASSE.url.iconTestCase
            }
          },
          test_suite : {
            valid_children : ["test_suite", "test_case"],
            icon : {
              image : IMPASSE.url.iconTestSuite
            }
          },
          test_project : {
            valid_children : ["test_suite", "test_case"],
            icon : {
              image : IMPASSE.url.iconProject
            },
            start_drag : false,
            move_node : false,
            delete_node : false,
            remove : false
          }
        }
      }
    })
    .bind("loaded.jstree refresh.jstree", function (e, data) {
      if (location.hash && location.hash.lastIndexOf("#test_case-", 0) == 0) {
        var node_id = "#exec_" + location.hash.replace(/^#test_case-/, "");
        jQuery("#testplan-tree").jstree('deselect_all');
        jQuery("#testplan-tree").jstree('select_node', node_id);
      }
    })
    .bind("select_node.jstree", function(e, data) {
      var node_id = data.rslt.obj.attr("id").replace("exec_", "");
      var node_type = data.rslt.obj.attr("rel");
      if(node_type == 'test_case'){
        location.replace("#test_case-" + node_id);
        $('#ajax-indicator').show();
        show_test_case(node_id);
      }
    });

  $('#bug_issue').live('focus', function(){
    $(this).autocomplete({
      source: IMPASSE.url.autocompleteIssue,
      minLength: 2,
      search: function(){$('#bug_issue').removeClass('ajax-loading');},
      response: function(){$('#bug_issue').removeClass('ajax-loading');}
    });
  });

  $("#add-issue-bug").live('click', function(){
    var issue_id = $("#bug_issue").val();
    var execution_id = $("#execution_id").val();
    $.ajax({
      url : IMPASSE.url.executionIssueAdd,
      type : 'POST',
      data : { 'execution_bug[execution_id]': execution_id, 'execution_bug[issue_id]': issue_id },
      success : function(data) {
        $("#executions-view form").submit();
      }
    });
    return false;
  });

  //Status Edit Form
  $('#status_execution_label').live('click', function(){
    $(this).prev('input:radio').attr('checked', true).change();
  });
  $("input[name='execution[status]']").live('change', function(){
     var status = $(this).val();
     if(status == 2){
       $("#add_issue_to_bug").show();
     }
     else {
       $("#add_issue_to_bug").hide();
     }
  });

  //Filters Form
  $("input[name=execution_status]").change(function() {
    var checked = $("input[name=execution_status]:checked");
    if (checked.size() > 0) {
      $("#cb_execution_status_all").removeAttr("checked").removeAttr("disabled").one("change", function() {
        $("input[name=execution_status]").removeAttr("checked");
        $("#cb_execution_status_all").attr("checked", "checked").attr("disabled", "disabled");
      });
    }
    else {
      $("#cb_execution_status_all").attr("checked", "checked").attr("disabled", "disabled").unbind("change");
    }
  });

  $("p.buttons a.icon.icon-checked").click(function(e) {
    $('#ajax-indicator').show();
    $tree.jstree("refresh");
    return false;
  });
  $("#executions-view form").live("submit", function(e) {
    var $this = $(this);
    var execution_status = $this.find(":radio[name='execution[status]']:checked").val();
    $.ajax({
      url : IMPASSE.url.executionsPut,
      type : 'POST',
      data : $this.serialize() + "&record=true",
      success : function(data) {
        show_notification_dialog(data.status, data.message);
        if (data.errors) {
          var ul = $("<ul/>");
          $.each(data.errors, function(i, error) {
            ul.append($("<li/>").html(error));
          });
          $("#errorExplanation").html(ul).show();
        }
        else {
          $("#errorExplanation").hide();
          $tree.jstree("refresh");
          var test_case_id = $("input[name='test_plan_case[test_case_id]']").val();
          show_test_case(test_case_id);
        }
      },
      complete : function(data) {
        $('#ajax-indicator').hide();
      }
    });
    return false;
  });

});
