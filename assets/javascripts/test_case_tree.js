jQuery.noConflict();
jQuery(document).ready(function ($) {
  var topPadding_test_case_view = 15;
  var offset_test_case_view = $("#test-case-fixed").offset();

  $(window).bind('scroll', function() {
    if ($(window).scrollTop() > offset_test_case_view.top) {
      $("#test-case-fixed").stop().animate({marginTop: $(window).scrollTop() - offset_test_case_view.top + topPadding_test_case_view}, 0);
    }
    else {
      $("#test-case-fixed").stop().animate({marginTop: 0}, 0);
    }
  });

  var LEAF_MENU = {
    contextmenu: {
      edit: {
        label: IMPASSE.label.buttonEdit,
        icon:  IMPASSE.url.iconEdit,
        action: function(node) { 
          var node_id = node.attr("id").replace("node_","");
          if(node.attr('rel') == 'test_case'){
            window.location.href = IMPASSE.url.testCaseEdit + '/' + node_id;
          }
          if(node.attr('rel') == 'test_suite'){
            window.location.href = IMPASSE.url.testSuiteEdit + '/' + node_id;
          }
        }
      },
      copy: {
        label: IMPASSE.label.buttonCopy,
        icon:  IMPASSE.url.iconCopy,
        action: function(node) {
          this.copy(node);
        }
      },
      remove: {
        label: IMPASSE.label.buttonDelete,
        icon:  IMPASSE.url.iconDelete,
        action: function(node) {
          if (confirm(IMPASSE.label.textAreYouSure)) {
            this.remove(node);
          }
        }
      }
    }
  };

  var FOLDER_MENU = {
    contextmenu: {
      create: {
        label: IMPASSE.label.buttonCreate,
        icon:  IMPASSE.url.iconAdd,
        submenu: {
          createTestSuite: {
            label: "Test suite",
            icon: IMPASSE.url.iconTestSuite,
            action: function(node) {
              var parent_id = node.attr("id").replace("node_","")
              window.location.href = IMPASSE.url.testSuiteNew + '?node_type=test_suite&node[parent_id]=' + parent_id;
            }
          },
          createTestCase: {
            label: "Test case",
            icon: IMPASSE.url.iconTestCase,
            action: function(node) {
              var parent_id = node.attr("id").replace("node_","")
              window.location.href = IMPASSE.url.testCaseNew + '?node_type=test_case&node[parent_id]=' + parent_id;
            }
          }
        }
      },
      edit: LEAF_MENU.contextmenu.edit,
      copy: LEAF_MENU.contextmenu.copy,
      paste: {
        label: "Paste",
        action: function(node) { this.paste(node); }
      },
      remove: LEAF_MENU.contextmenu.remove
    }
  };

  var ROOT_MENU = {
    contextmenu: {
      create: FOLDER_MENU.contextmenu.create,
      paste:  FOLDER_MENU.contextmenu.paste
    }
  };

  function show_node(node_id, node_type){
    if(node_type=='test_case'){
      show_url = IMPASSE.url.testCaseShow
    }
    if(node_type=='test_suite'){
      show_url = IMPASSE.url.testSuiteShow
    }
    $.ajax({
      url: show_url + '/' + node_id,
      success: function(html) {
        var winHeight = $(window).height();
        var $testCaseView = $("#test-case-view");
        $testCaseView.css({height:'', overflow:''}).html(html).show();
        if ($testCaseView.height() > winHeight) {
          $testCaseView.height(winHeight - 1).css('overflow', 'scroll');
        }
      },
      error: ajax_error_handler,
      complete: function() {
        $("#test-case-view").unblock();
      }
    });
  }

  function split( val ) {
    return val.split( /,\s*/ );
  }

  function extractLast( term ) {
    return split( term ).pop();
  }

  function setupKeyword(completeBox, availableTags) {
    completeBox.autocomplete({
      minLength: 0,
      source: function(request, response) {
        response($.ui.autocomplete.filter(availableTags, extractLast(request.term)));
      },
      focus: function() {
        // prevent value inserted on focus
        return false;
      },
      select: function( event, ui ) {
        var terms = split( this.value );
        // remove the current input
        terms.pop();
        // add the selected item
        terms.push( ui.item.value );
        // add placeholder to get the comma-and-space at the end
        terms.push( "" );
        this.value = terms.join( ", " );
        return false;
      }
    });
  }

  var plugins = ["themes","json_data","ui","types", "hotkey"];
  if (IMPASSE.canEdit) {
    plugins = plugins.concat(["crrm","dnd","contextmenu", "checkbox"]);
  }

  var prepared_checkbox = false;
  var testcaseTree =$("#testcase-tree")
    .jstree({ 
      plugins: plugins,
      core: {
        animation: 0
      },
      contextmenu: {
        select_node: true,
        items: function(node) {
          if (node.attr('rel') == 'test_project'){
            return ROOT_MENU.contextmenu;
          }
          else if (node.attr('rel') == 'test_suite'){
            return FOLDER_MENU.contextmenu;
          }
          else if (node.attr('rel') == 'test_case'){
            return LEAF_MENU.contextmenu;
          }
        }
      },
      json_data: { 
        ajax: {
          url: IMPASSE.url.testCaseList,
          data: function (n) {
            var data = {
              prefix: "node", 
              node_id: n.attr ? n.attr("id").replace("node_","") : -1
            };
            $("#filters").find(":text[name],:checkbox:checked").each(function() {
              var el = $(this);
              if (el.val())
              data[el.attr("name")] = el.val();
            });
            return data;
          }
        }
      },
      types: {
        max_depth: -2,
        max_children: -2,
        valid_children: [ "test_project" ],
        types: {
          test_case: {
            valid_children: "none",
            icon: {
              image: IMPASSE.url.iconTestCase
            }
          },
          test_suite: {
            valid_children: [ "test_suite", "test_case" ],
            icon: {
              image: IMPASSE.url.iconTestSuite
            }
          },
          test_project: {
            valid_children: [ "test_suite", "test_case" ],
            icon: {
              image: IMPASSE.url.iconProject
            },
            start_drag: false,
            move_node: false,
            delete_node: false,
            remove: false
          }
        }
      },
      dnd: {
        drag_finish: function(data) {
          var $this = this;
          var draggable = $(data.o).hasClass("jstree-draggable") ? $(data.o) : $(data.o).parents(".jstree-draggable");
          var request = {
            "issue_id": draggable.attr("id").replace("issue-", ""),
            "test_case_id": data.r.attr("id").replace("node_", "")
          };
          $.ajax({
            type: 'POST',
            url: IMPASSE.url.requirementIssuesAddTestCase,
            data: request,
            success: function(r) {
              show_notification_dialog(r.status, r.message);
            },
            error: function(xhr, status, ex) {
              ajax_error_handler(xhr, status, ex);
            }
          });
        }
      },
      checkbox: {
        two_state: false
      }
    })
    .bind("loaded.jstree refresh.jstree", function (e, data) {
      if (!prepared_checkbox) {
        testcaseTree.jstree('hide_checkboxes');
        prepared_checkbox = true;
      }
      if (location.hash && location.hash.lastIndexOf("#test_case-", 0) == 0) {
        var node_id = "#node_" + location.hash.replace(/^#test_case-/, "");
        jQuery("#testcase-tree").jstree('deselect_all');
        jQuery("#testcase-tree").jstree('select_node', node_id);
      }
      if (location.hash && location.hash.lastIndexOf("#test_suite-", 0) == 0) {
        var node_id = "#node_" + location.hash.replace(/^#test_suite-/, "");
        jQuery("#testcase-tree").jstree('deselect_all');
        jQuery("#testcase-tree").jstree('select_node', node_id);
      }
    })
    .bind("remove.jstree", function (e, data) {
      var request = {"node[id]": []};
      data.rslt.obj.each(function() {
        request["node[id]"].push(this.id.replace("node_", ""));
      });
      $.ajax({
        async: false,
        type: 'DELETE',
        url: IMPASSE.url.testCaseDestroy,
        data: request,
        success: function (r) {
          if(!r.status) {
            $.jstree.rollback(data.rlbk);
          }
          data.inst.refresh();
        },
        error: function(xhr, status, ex) {
          ajax_error_handler(xhr, status, ex);
          $.jstree.rollback(data.rlbk);
        }
      });
    })
    .bind("copy.jstree", function(e, data) {
    })
    .bind("move_node.jstree", function (e, data) {
      $("#testcase-tree").block(impasse_loading_options());
      var url = (data.rslt.cy) ? IMPASSE.url.testCaseCopy : IMPASSE.url.testCaseMove;
      var request = {};
      data.rslt.o.each(function (i, node) {
        request["nodes["+i+"][id]"]         = $(node).attr("id").replace("node_","");
        request["nodes["+i+"][parent_id]"]  = data.rslt.cr === -1 ? 1 : data.rslt.np.attr("id").replace("node_","");
        request["nodes["+i+"][node_order]"] = data.rslt.cp + i;
      });
      if (data.rslt.cy) {
        data.rslt.oc.each(function(i, node) {
          request["nodes["+i+"][original_id]"] = $(node).attr("id").replace("copy_node_","");
        });
      }
      var dest = $(data.rslt.oc);
      $("ins.jstree-icon", dest).css({backgroundImage: "url(" + IMPASSE.url.iconLoading + ")"});
      $.ajax({
        type: 'POST',
        url: url,
        data: request,
        success : function (r) {
          if(!r || r.length == 0) {
            $.jstree.rollback(data.rlbk);
          }
          else {
            dest.each(function(i) {
              var node = $(this);
              node.attr("id", "node_" + r[i].id);
              data.inst.set_text(node, r[i].id + ' - ' + r[i].name);
              node.data("jstree", (dest.attr("rel")=="test_case") ? LEAF_MENU : FOLDER_MENU);
              if(data.rslt.cy && dest.children("UL").length) {
                data.inst.refresh();
              }
            });
            $("ins.jstree-icon", dest).css("backgroundImage", "");
          }
          $("#testcase-tree").unblock();
        },
        error: function(xhr, status, ex) {
          $("#testcase-tree").unblock();
          $.jstree.rollback(data.rlbk);
          ajax_error_handler(xhr, status, ex);
        }
      });
    })
    .bind("select_node.jstree", function(e, data) {
      var node_id = data.rslt.obj.attr("id").replace("node_", "");
      var node_type = data.rslt.obj.attr("rel");
      if(node_type == 'test_case' || node_type == 'test_suite'){
        $("#test-case-view").block(impasse_loading_options());
        location.replace("#" + node_type + '-' + node_id);
        show_node(node_id, node_type);
      }
    });

  $(".splitcontentright .floating").floatmenu();

  $.getJSON(IMPASSE.url.testKeywords, function(json) {
    setupKeyword($(".filter :input#filters_keywords"), json);
  });

  $("#button-requirement-issues").bind("click", function(e) {
    $.ajax({
      url: IMPASSE.url.requirementIssues,
      data: { },
      success: function(html) {
        $("#requirements-view").html(html).show();
      },
      error: ajax_error_handler
    });
  });

  $("#button-close-requirements").live("click", function(e) {
    $("#requirements-view").hide();
    e.preventDefault();
  });

});

