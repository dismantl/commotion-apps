var currentTab;
window.onload=function() { filter_apps('new'); }
function filter_apps(filter) {
  currentTab = filter;
  // add/remove 'active' class to tabs
  var tabs = document.getElementById('tabs').getElementsByTagName('li');
  for (var i=0;i < tabs.length;i++) {
    if (tabs[i].children[0].id === currentTab + '_apps') {
      // add 'active' class
      if (!tabs[i].className.match(/(?:^|\s)active(?!\S)/)) { tabs[i].className += ' active'; }
      tabs[i].className = tabs[i].className.replace(/(?:^|\s)cbi-tab-disabled(?!\S)/g,' cbi-tab');
    } else {
      // remove 'active' class
      tabs[i].className = tabs[i].className.replace(/(?:^|\s)active(?!\S)/g,'');
      tabs[i].className = tabs[i].className.replace(/(?:^|\s)cbi-tab(?!\S)/g,' cbi-tab-disabled');
    }
  }

  var categories = document.getElementById('types').children;
  //console.log(categories);
  for(var i=0;i < categories.length;i++) {
    //console.log(categories[i]);
    var apps = categories[i].lastElementChild.children;
    var relevantApps = false;
    for(var j=0;j < apps.length;j++) {
      //console.log(apps[j]);
      // if no apps of type matching current tab, hide category
      if((' ' + apps[j].className + ' ').indexOf(' ' + currentTab + ' ') > -1) {
        relevantApps = true;
        apps[j].style.display = "block";
      } else {
        apps[j].style.display = "none";
      }
    }
    if (!relevantApps) {
      //hide category
      categories[i].style.display = "none";
    } else {
      categories[i].style.display = "block";
    }
  }
}
function JudgeApp(app,approved) {
        var action, ajax = new XHR();
	if (approved == 1) {
		action = "approved";
	} else {
		action = "blacklisted";
	} // FIXME! can be made more efficient a ? b : c
        ajax.post(
        	window.location.pathname + '/judge',
        	{
			uuid:app,
			approved:approved
		},
        	function(resp){
        		console.log(resp.status);
        		if (resp.status !== 200) {
        			console.log('error!');
        		} else {
        			var elems = document.getElementsByTagName('*');
                                for (var i in elems) {
                                        if((' ' + elems[i].className + ' ').indexOf(' ' + app + ' ') > -1) {
                                                elems[i].className = "app " + action + " " + app;
                                        }
                                }
                                filter_apps(currentTab);
        		}
        	}
        );
	return false;
}