ruleset ruleset_registry {
  meta {
    name "Register ruleset"
    description <<
Ruleset for registering other rulesets
>>
    author "PJW"
    logging off

    use module b16x24 alias system_credentials

    sharing on
    provides listRulesets

  } 

  global { 

    listRulesets = function(developer_eci) {
      rid_list = rsm:list_rulesets(developer_eci);
      rid_list
    }
  }

 rule register_ruleset {
   select when system new_ruleset_registration
   pre {
     rid = event:attr("new_rid").klog(">>>>  new rid >>>> ");
     passphrase = event:attr("passphrase").klog(">>>> given pp >>>> ");
     developer_eci = event:attr("developer_eci").klog(">>>> eci >>>>");
     uri = event:attr("new_uri").klog(">>>> uri >>>> ");
     expected_pp = keys:system_credentials("passphrase").klog(">>> pp >>>>");
   }

   if( passphrase eq expected_pp
    && ! uri.isnull()
    && ! rid.isnull()
     ) then 
   {
      
      rsm:create(rid) setting (isCreated)
        with owner = developer_eci
	 and uri = uri;

      send_directive("ruleset_registered") with
        rid = rid and 
	owner = developer_eci and 
	uri = uri;
 
   }

   fired {
     log ">>>>> created ran >>>>> " + isCreated;
   }

 }

 rule delist_ruleset {
   select when system delete_ruleset_registration
   pre {
     rid = event:attr("new_rid").klog(">>>>  rid to delete >>>> ");
     passphrase = event:attr("passphrase").klog(">>>> given pp >>>> ");
     expected_pp = keys:system_credentials("passphrase").klog(">>> pp >>>>");
   }

   if(passphrase eq expected_pp) then 
   {
      
      rsm:delete(rid) setting (isDelete);
      send_directive("deleting_ruleset") with
        rid = rid;
 
   }
   fired {
     log ">>>>> deleted ran >>>>> " + isCreated;
   }
 }



}
