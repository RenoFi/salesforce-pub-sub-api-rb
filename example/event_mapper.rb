module Example
  class EventMapper
    def self.build(**fields)
      # will be changed, just a payload example
      {
        "ChangeEventHeader": {
          "entityName": "Game__c",
          "recordIds": ["a33TH000000MmZ3YAK"],
          "changeType": "UPDATE",
          "changeOrigin": "com/salesforce/api/soap/61.0;client=OurClient/",
          "transactionKey": "00002b0d-5c3b-1442-530b-64a22139ad1c",
          "sequenceNumber": 1,
          "commitTimestamp": 1724440941000,
          "commitNumber": 1724440941229694978,
          "commitUser": "005f4000004ICzNAAW",
          "nulledFields": [],
          "diffFields": [],
          "changedFields": []
        },
        "OwnerId": nil,
        "Name": "Testings",
        "CreatedDate": nil,
        "CreatedById": nil,
        "LastModifiedDate": 1724440941000,
        "LastModifiedById": nil,
        "Category__c": nil,
        "Public_Rating__c": nil,
        "Record_UUID__c": record_id
      }
    end
  end
end