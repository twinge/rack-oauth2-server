(function() {
  Sammy("#main", function(app) {
    var api, commonScope, mergeScope, noticeTimeout, withCommonScope;
    this.use(Sammy.Tmpl);
    this.use(Sammy.Session);
    this.use(Sammy.Title);
    this.setTitle("OAuth Admin - ");
    this.use(Sammy.OAuth2);
    this.authorize = document.location.pathname + "/authorize";
    $(document).ajaxError(function(evt, xhr) {
      if (xhr.status === 401) {
        app.loseAccessToken();
      }
      return app.trigger("notice", xhr.responseText);
    });
    $(document).ajaxStart(function(evt) {
      return $("#throbber").show();
    });
    $(document).ajaxStop(function(evt) {
      return $("#throbber").hide();
    });
    this.requireOAuth();
    this.bind("oauth.denied", function(evt, error) {
      return app.partial("admin/views/no_access.tmpl", {
        error: error.message
      });
    });
    this.bind("oauth.connected", function() {
      $("#header .signin").hide();
      return $("#header .signout").show();
    });
    this.bind("oauth.disconnected", function() {
      $("#header .signin").show();
      return $("#header .signout").hide();
    });
    api = "" + document.location.pathname + "/api";
    mergeScope = function(scope) {
      if ($.isArray(scope)) {
        scope = scope.join(" ");
      }
      scope = (scope || "").trim().split(/\s+/);
      if (scope.length === 1 && scope[0] === "") {
        return [];
      } else {
        return _.uniq(scope).sort();
      }
    };
    commonScope = null;
    withCommonScope = function(cb) {
      if (commonScope) {
        return cb(commonScope);
      } else {
        return $.getJSON("" + api + "/clients", function(json) {
          return cb(commonScope = json.scope);
        });
      }
    };
    this.get("#/", function(context) {
      context.title("All Clients");
      return $.getJSON("" + api + "/clients", function(clients) {
        commonScope = clients.scope;
        return context.partial("admin/views/clients.tmpl", {
          clients: clients.list,
          tokens: clients.tokens
        }).load(clients.history).then(function(json) {
          return $("#fig").chart(json.data, "granted");
        });
      });
    });
    this.get("#/client/:id", function(context) {
      return $.getJSON("" + api + "/client/" + context.params.id, function(client) {
        context.title(client.displayName);
        client.notes = (client.notes || "").split(/\n\n/);
        return context.partial("admin/views/client.tmpl", client).load(client.history).then(function(json) {
          return $("#fig").chart(json.data, "granted");
        });
      });
    });
    this.get("#/client/:id/page/:page", function(context) {
      return $.getJSON("" + api + "/client/" + context.params.id + "?page=" + context.params.page, function(client) {
        context.title(client.displayName);
        client.notes = client.notes.split(/\n\n/);
        return context.partial("admin/views/client.tmpl", client).load(client.history).then(function(json) {
          return $("#fig").chart(json.data, "granted");
        });
      });
    });
    this.post("#/token/:id/revoke", function(context) {
      return $.post("" + api + "/token/" + context.params.id + "/revoke", function() {
        return context.redirect("#/");
      });
    });
    this.get("#/client/:id/edit", function(context) {
      return $.getJSON("" + api + "/client/" + context.params.id, function(client) {
        context.title(client.displayName);
        return withCommonScope(function(scope) {
          client.common = scope;
          return context.partial("admin/views/edit.tmpl", client);
        });
      });
    });
    this.put("#/client/:id", function(context) {
      context.params.scope = mergeScope(context.params.scope);
      return $.ajax({
        type: "put",
        url: "" + api + "/client/" + context.params.id,
        data: {
          displayName: context.params.displayName,
          link: context.params.link,
          imageUrl: context.params.imageUrl,
          redirectUri: context.params.redirectUri,
          notes: context.params.notes,
          scope: context.params.scope
        },
        success: function(client) {
          context.redirect("#/client/" + context.params.id);
          return app.trigger("notice", "Saved your changes");
        },
        error: function(xhr) {
          return withCommonScope(function(scope) {
            context.params.common = scope;
            return context.partial("admin/views/edit.tmpl", context.params);
          });
        }
      });
    });
    this.del("#/client/:id", function(context) {
      return $.ajax({
        type: "post",
        url: "" + api + "/client/" + context.params.id,
        data: {
          _method: "delete"
        },
        success: function() {
          return context.redirect("#/");
        }
      });
    });
    this.post("#/client/:id/revoke", function(context) {
      return $.post("" + api + "/client/" + context.params.id + "/revoke", function() {
        return context.redirect("#/");
      });
    });
    this.get("#/new", function(context) {
      context.title("Add New Client");
      return withCommonScope(function(scope) {
        return context.partial("admin/views/edit.tmpl", {
          common: scope,
          scope: scope
        });
      });
    });
    this.post("#/clients", function(context) {
      context.title("Add New Client");
      context.params.scope = mergeScope(context.params.scope);
      return $.ajax({
        type: "post",
        url: "" + api + "/clients",
        data: {
          displayName: context.params.displayName,
          link: context.params.link,
          imageUrl: context.params.imageUrl,
          redirectUri: context.params.redirectUri,
          notes: context.params.notes,
          scope: context.params.scope
        },
        success: function(client) {
          app.trigger("notice", "Added new client application " + client.displayName);
          return context.redirect("#/");
        },
        error: function(xhr) {
          return withCommonScope(function(scope) {
            context.params.common = scope;
            return context.partial("admin/views/edit.tmpl", context.params);
          });
        }
      });
    });
    this.get("#/signout", function(context) {
      context.loseAccessToken();
      return context.redirect("#/");
    });
    $("a[data-method]").live("click", function(evt) {
      var form, link, method;
      evt.preventDefault;
      link = $(this);
      if (link.attr("data-confirm") && !confirm(link.attr("data-confirm"))) {
        return false;
      }
      method = link.attr("data-method") || "get";
      form = $("<form>", {
        style: "display:none",
        method: method,
        action: link.attr("href")
      });
      if (method !== "get" && method !== "post") {
        form.append($("<input name='_method' type='hidden' value='" + method + "'>"));
      }
      app.$element().append(form);
      form.submit();
      return false;
    });
    noticeTimeout = null;
    app.bind("notice", function(evt, message) {
      if (!message || message.trim() === "") {
        message = "Got an error, but don't know why";
      }
      $("#notice").text(message).fadeIn("fast");
      if (noticeTimeout) {
        clearTimeout(noticeTimeout);
        noticeTimeout = null;
      }
      return noticeTimeout = setTimeout(function() {
        noticeTimeout = null;
        return $("#notice").fadeOut("slow");
      }, 5000);
    });
    return $("#notice").live("click", function() {
      return $(this).fadeOut("slow");
    });
  });
  $.thousands = function(integer) {
    return integer.toString().replace(/^(\d+?)((\d{3})+)$/g, function(x, a, b) {
      return a + b.replace(/(\d{3})/g, ",$1");
    }).replace(/\.((\d{3})+)(\d+)$/g, function(x, a, b, c) {
      return "." + a.replace(/(\d{3})/g, "$1,") + c;
    });
  };
  $.shortdate = function(integer) {
    var date;
    date = new Date(integer * 1000);
    return "<abbr title='" + (date.toLocaleString()) + "'>" + (date.toDateString().substring(0, 10)) + "</abbr>";
  };
  $.fn.chart = function(data, series) {
    var canvas, h, max, today, vis, w, x, y;
    if (typeof pv === "undefined") {
      return;
    }
    canvas = $(this);
    w = canvas.width();
    h = canvas.height();
    today = Math.floor(new Date() / 86400000);
    x = pv.Scale.linear(today - 60, today + 1).range(0, w);
    max = pv.max(data, function(d) {
      return d[series];
    });
    y = pv.Scale.linear(0, pv.max([max, 10])).range(0, h);
    vis = new pv.Panel().width(w).height(h).bottom(20).left(20).right(10).top(5);
    vis.add(pv.Rule).data(x.ticks()).left(x).strokeStyle("#fff").add(pv.Rule).bottom(-5).height(5).strokeStyle("#000").anchor("bottom").add(pv.Label).text(function(d) {
      return pv.Format.date("%b %d").format(new Date(d * 86400000));
    });
    vis.add(pv.Rule).data(y.ticks(3)).bottom(y).strokeStyle(function(d) {
      if (d) {
        return "#ddd";
      } else {
        return "#000";
      }
    }).anchor("left").add(pv.Label).text(y.tickFormat);
    if (data.length === 1) {
      vis.add(pv.Dot).data(data).left(function(d) {
        return x(new Date(d.ts));
      }).bottom(function(d) {
        return y(d[series]);
      }).radius(3).lineWidth(2);
    } else {
      vis.add(pv.Line).data(data).interpolate("linear").left(function(d) {
        return x(new Date(d.ts));
      }).bottom(function(d) {
        return y(d[series]);
      }).lineWidth(3);
    }
    return vis.canvas(canvas[0]).render();
  };
}).call(this);