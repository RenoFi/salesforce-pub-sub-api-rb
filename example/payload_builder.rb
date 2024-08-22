class PayloadBuilder
  def self.build(decoded_event)
    decoded_event["ChangeEventHeader"]["changeOrigin"] = "com/salesforce/api/soap/61.0;client=OurClient/"
    decoded_event["Record_UUID__c"] = SecureRandom.uuid
    decoded_event
  end
end
