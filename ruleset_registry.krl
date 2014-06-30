ruleset ruleset_registry {
  meta {
    name "Register ruleset"
    description <<
Ruleset for registering other rulesets
>>
    author "PJW"
    logging off

    use module b16x24 alias system_credentials

  }

 rule register_ruleset {
   select when system new_ruleset_registration
   pre {
     rid = event:attr("rid").klog(">>>>  new rid >>>> ");
     passphrase = event:attr("passphrase").klog(">>>> given pp >>>> ");
     developer_eci = event:attr("developer_eci").klog(">>>> eci >>>>");
     uri = event:attr("uri").klog(">>>> uri >>>> ");
     expected_pp = keys:system_credentials("passphrase").klog(">>> pp >>>>");
   }

   if(passphrase eq expected_pp) then 
   {
      
      rsm:create(rid) setting (isCreated)
        with owner = developer_eci
	 and uri = uri;
 
   }

 }

 rule delist_ruleset {
   select when system delete_ruleset_registration
   pre {
     rid = event:attr("rid").klog(">>>>  rid to delete >>>> ");
     passphrase = event:attr("passphrase").klog(">>>> given pp >>>> ");
     expected_pp = keys:system_credentials("passphrase").klog(">>> pp >>>>");
   }

   if(passphrase eq expected_pp) then 
   {
      
      rsm:delete(rid) setting (isCreated)
 
   }

 }



}
