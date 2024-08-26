# Pub/Sub API Ruby - CDC Salesforce example

This is a Pub/Sub API example made entirely in Ruby.

It provides the necessary to communicate with the Pub/Sub Salesforce API (Change Data Capture)

## Setup

This section provides the necessary instructions to run the project as well as subscribe to a topic

The custom object that we are going to listen is already set and created.

You should perform actions like: create, edit, etc... through [UI Custom Object in SF](https://renofi--stag.sandbox.lightning.force.com/lightning/o/Game__c/home) - login with staging 1pass credentials

**Commands**

1. `bundle install`
2. `bin/console`

```console
irb:001 > example = Example::App.new
irb:002 > example.run

Subscribed to .... (topic name)

# events will appear here as soon as you perform any operations on the UI
```

## Useful documentation
1. [Change Data Capture docs](https://trailhead.salesforce.com/content/learn/modules/change-data-capture)
2. [How to create a subscription](https://trailhead.salesforce.com/content/learn/modules/change-data-capture/subscribe-to-events#subscribe-using-pub-sub-api)
3. [Pub/Sub API GitHub Repo](https://github.com/forcedotcom/pub-sub-api)
4. [Demo video on how Pub/Sub API works](https://www.youtube.com/watch?v=g9P87_loVVA)
5. [What is gRPC?](https://grpc.io/docs/what-is-grpc/)
6. [Pub/Sub API developer documentation](https://developer.salesforce.com/docs/platform/pub-sub-api/overview)
