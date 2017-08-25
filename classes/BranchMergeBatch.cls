public with sharing class BranchMergeBatch implements Database.batchable<sobject>,Database.AllowsCallouts,Database.Stateful
{
    // updated	
    private String query ='SELECT Id FROM Branch__c WHERE Id=\'\'';
    private Id branchId;
    
    // to get Prefix name
    private String nameSpacePrefix;
    private String className = 'BranchMergeBatch';
    private String objectName = 'Component__c';
    private String fullObjectName = 'Component__c';

    private Map<String,Id> rTypMap;
    private DateTime branchLastUpdatedDate;
    private Set<Id> itemsInSet = new Set<Id>();
    private Id buildId;
    private Id commitId;
    
    public BranchMergeBatch(Id branchId,Id buildId, Set<Id> itemsInSet, Id commitId)
    {
    	this.commitId = commitId;
        this.buildId = buildId;
        rTypMap = new Map<String,Id>();
        this.itemsInSet = itemsInSet;
        this.branchId = branchId;
        this.query = 'SELECT Id,Branch__c,Component_Name__c,CRC32__c,Comments__c,Last_Updated_By__c,LastModifiedDate,Component_Type__c,Version__c,Last_Modified_By__c,Last_Modified_Date__c,File_Name__c,(Select Id,Component__c FROM Components__r ORDER BY Version__c DESC LIMIT 1) FROM Component__c WHERE Branch__c=:branchId AND Id IN:itemsInSet AND RecordType.Name=\''+'Branch\'';
        
        fullObjectName = Schema.sObjectType.Component__c.getName();
        //collection record types
        for(RecordType rt :[SELECT Id,Name From RecordType Where SobjectType =:fullObjectName AND (Name='Repository' OR Name='Branch') LIMIT 2])
            rTypMap.put(rt.Name,rt.Id); 
            
        List<Branch__c> branchList = new List<Branch__c>();
        branchList = [SELECT Id,CreatedDate FROM Branch__c WHERE Id=:branchId LIMIT 1];
        if(branchList.size() == 1)
        {
            branchLastUpdatedDate = branchList[0].CreatedDate;
        }
    }
    
    public Database.QueryLocator start(Database.BatchableContext BC)
    {
        return Database.getQueryLocator(query);
    }
    
    // Batch size must be 1
    public void execute(Database.BatchableContext info, List<sObject> scope)
    {
        List<Component__c> componentList = (List<Component__c>) scope;
        if(componentList.size() > 0)
        {
            if(rTypMap.size() == 2)
            {
                List<Component__c> updateList = new List<Component__c>();
                List<Component__c> insertList = new List<Component__c>();
                List<Component_History__c> historyList = new List<Component_History__c>();
                Map<String,Component__c> itemMap = new Map<String,Component__c>();
                Set<Id> historyIdSet = new Set<Id>();
                
                Set<String> metaRecordTypeSet = new Set<String>();
                Set<String> metaFullNameSet = new Set<String>();
                //create new map of components should be created to repository from branch
                for(Component__c newComp:componentList)
                {
                    if(newComp.Components__r != null && newComp.Components__r.size() == 1)
                    {
                        itemMap.put(newComp.Component_Type__c+'#'+newComp.Component_Name__c, newComp);
                        metaRecordTypeSet.add(newComp.Component_Type__c);
                        metaFullNameSet.add(newComp.Component_Name__c);
                        historyIdSet.add(newComp.Components__r[0].Id);
                    }
                }
                
                if(itemMap.size() > 0)
                {
                    // remove from map if allready find in repository,update existed component reocrd and create lattest history record.
                    for(Component__c comp : [SELECT Id,Component_Type__c,CRC32__c,Component_Name__c,LastModifiedDate,Version__c,Name, Last_Modified_Date__c FROM Component__c WHERE RecordTypeId=:rTypMap.get('Repository') AND Component_Name__c IN:metaFullNameSet AND Component_Type__c IN:metaRecordTypeSet])
                    {
                        String temp = comp.Component_Type__c+'#'+comp.Component_Name__c;
                        if(itemMap.containsKey(temp))
                        {
                            Component__c updateComp = itemMap.get(temp);
                            
                            //creating component history
                            Component_History__c history = new Component_History__c(Component__c=comp.Id,Version__c=comp.Version__c+1,CRC32__C=updateComp.CRC32__c);
                            historyList.add(history);
                            
                            //updating old record
                            comp.File_Name__c = updateComp.File_Name__c;
                            //comp.Last_Modified_By__c = updateComp.Last_Modified_By__c;
                            comp.Last_Modified_Date__c = updateComp.Last_Modified_Date__c;
                            comp.Last_Updated_By__c = updateComp.Last_Updated_By__c;
                            comp.Version__c= comp.Version__c+1;
                            comp.Comments__c = updateComp.Comments__c;
                            comp.CRC32__c = updateComp.CRC32__c;
                            updateList.add(comp);
                            
                            //remove record from map
                            itemMap.remove(temp);
                        }
                    }
                    for(Component__c branchComp :itemMap.values())
                    {
                        Component__c comp = new Component__c();
                        comp.Component_Name__c= branchComp.Component_Name__c;
                        comp.Component_Type__c =  branchComp.Component_Type__c;
                        comp.File_Name__c =  branchComp.File_Name__c;
                        //comp.Last_Modified_By__c =  branchComp.Last_Modified_By__c;
                        comp.Last_Modified_Date__c =  branchComp.Last_Modified_Date__c;
                        comp.Last_Updated_By__c = branchComp.Last_Updated_By__c;
                        comp.Comments__c = branchComp.Comments__c;
                        comp.Version__c=1;
                        comp.CRC32__c = branchComp.CRC32__c;
                        comp.RecordTypeId=rTypMap.get('Repository');
                        insertList.add(comp);
                    }
                    if(updateList.size() > 0)
                    {
                        update updateList;
                    }
                    //insert new component and add Component History reocrds to list
                    if(insertList.size() > 0)
                    {
                        insert insertList;
                        for(Component__c comp: insertList)
                        {
                            Component_History__c history = new Component_History__c(Component__c=comp.Id,Version__c=comp.Version__c,CRC32__C=comp.CRC32__c);
                            historyList.add(history);
                        }
                        insertList.clear();
                    }
                    // crate history records with attachments
                    if(historyList.size() > 0)
                    {
                        insert historyList;
                        if(this.buildId != null)
                        {
	                        List<Build_Manifest__c> maniList = new List<Build_Manifest__c>();
	                        for(Component_History__c his : historyList)
	                        {
	                            maniList.add(new Build_Manifest__c(Build__c = this.buildId,Component_History__c=his.Id));
	                        }
	                        if(maniList.size() > 0)
	                        {
	                            insert maniList;
	                            maniList.clear();
	                        }
                        }
                        if(this.commitId != null)
                        {
                        	List<Commit_Manifest__c> maniList = new List<Commit_Manifest__c>();
	                        for(Component_History__c his : historyList)
	                        {
	                            maniList.add(new Commit_Manifest__c(Commit__c = this.commitId,Component_History__c=his.Id));
	                        }
	                        if(maniList.size() > 0)
	                        {
	                            insert maniList;
	                            maniList.clear();
	                        }
                        }
                        //find attachment from branch
                        Map<String,Id> itemAttachmentMap = new Map<String,Id>();
                        for(Component_History__c history : [SELECT Id,Component__r.Component_Name__c ,Component__r.Component_Type__c,(SELECT Id FROM Attachments ORDER BY LastModifiedDate DESC LIMIT 1) FROM Component_History__c WHERE Id IN:historyIdSet])
                        {
                            if(history.Attachments != null && history.Attachments.size() == 1)
                            {
                                String key = history.Component__r.Component_Type__c+'#'+history.Component__r.Component_Name__c;
                                itemAttachmentMap.put(key,history.Attachments[0].Id);
                            }
                        }
                        //relate a branch history attachment to a new created history(repository)
                        Map<Id,Id> parentAttIdMap = new map<Id,Id>();
                        for(Component_History__c history : [SELECT Id,Component__c,Component__r.Component_Name__c ,Component__r.Component_Type__c FROM Component_History__c WHERE Id IN:historyList])
                        {
                            
                            String key = history.Component__r.Component_Type__c+'#'+history.Component__r.Component_Name__c;
                            if(itemAttachmentMap.containsKey(key))
                            {
                                parentAttIdMap.put(itemAttachmentMap.get(key),history.Id);
                            }
                        }
                        //clone attachments
                        List<Attachment> attList = new List<Attachment>();
                        for(Attachment att:[SELECT Id,Body,Name,Description,ContentType FROM Attachment WHERE Id IN:parentAttIdMap.keySet()])
                        {
                            Attachment att2 = att.clone();
                            att2.ParentId = parentAttIdMap.get(att.Id);
                            attList.add(att2);
                        }
                        if(attList.size() > 0)
                        {
                            insert attList;
                        }
                    }
                }
            }
        }
    }
    
    public void finish(Database.BatchableContext BC)
    {
        List<Build__c> buildList = new List<Build__c>();
        buildList = [SELECT Org__c FROM Build__c WHERE Id=:this.buildId LIMIT 1];
        if(buildList.size() == 1 && buildList[0].Org__c != null)
        {
            Database.executeBatch(new MergeDeployBatch(buildList[0].Id,buildList[0].Org__c),1);
        }
        else
        {
            List<Branch__c> branchList = new List<Branch__c>();
            branchList = [SELECT Id,Merged_to_Repository__c FROM Branch__c WHERE Id=:branchId LIMIT 1];
            if(branchList.size() == 1)
            {
                branchList[0].Merged_to_Repository__c = true;
                update branchList;
            }
        }
    }
}
