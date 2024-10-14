import ballerina/io;
import ballerina/lang.value;
import ballerinax/kafka;
import ballerinax/mongodb;

// MongoDB client configuration
mongodb:Client mongoClient = check new ({
    connection: {
        serverAddress: {
            host: "localhost",
            port: 27017
        },
        auth: <mongodb:ScramSha256AuthCredential>{
            username: "tuyoleni",
            password: "mango.tuyoleni",
            database: "admin"
        }
    }
});

public function main() returns error? {
    kafka:Consumer kafkaConsumer = check setupKafkaConsumer();
    io:println("Logistics service started. Waiting for requests...");

    // Main event loop
    while (true) {
        check processKafkaRecords(kafkaConsumer);
    }
}

// Setup Kafka consumer with specific configuration
function setupKafkaConsumer() returns kafka:Consumer|error {
    kafka:ConsumerConfiguration consumerConfigs = {
        groupId: "logistics-group",
        topics: ["delivery-requests", "tracking-requests", "delivery-confirmations"],
        pollingInterval: 1,
        autoCommit: false
    };
    return new (kafka:DEFAULT_URL, consumerConfigs);
}

// Process Kafka records
function processKafkaRecords(kafka:Consumer kafkaConsumer) returns error? {
    kafka:BytesConsumerRecord[] records = check kafkaConsumer->poll(1);
    foreach var rec in records {
        check processRecord(rec);
    }
}

// Process individual Kafka record
function processRecord(kafka:BytesConsumerRecord rec) returns error? {
    byte[] valueBytes = rec.value;
    string valueString = check string:fromBytes(valueBytes);

    string topic = rec.offset.partition.topic;

    // Simplified logging
    io:println("Processing record from topic: ", topic);

    match topic {
        "delivery-requests" => {
            check processDeliveryRequest(valueString);
        }
        "tracking-requests" => {
            check processTrackingRequest(valueString);
        }
        "delivery-confirmations" => {
            check processDeliveryConfirmation(valueString);
        }
        _ => {
            io:println("Unknown topic: ", topic);
        }
    }
}

// Process delivery request
function processDeliveryRequest(string requestStr) returns error? {
    json request = check value:fromJsonString(requestStr);

    // Simplified logging
    io:println("Processing Delivery Request: ", request.requestId);

    mongodb:Database logistics = check mongoClient->getDatabase("logistics");
    mongodb:Collection requests = check logistics->getCollection("requests");
    _ = check requests->insertOne(<map<json>>request);

    check forwardToService(check request.shipmentType, request);
}

// Process tracking request
function processTrackingRequest(string requestStr) returns error? {
    json request = check value:fromJsonString(requestStr);
    string requestId = check request.requestId;

    io:println("Processing Tracking Request: ", requestId);

    mongodb:Database logistics = check mongoClient->getDatabase("logistics");
    mongodb:Collection requests = check logistics->getCollection("requests");
    record {|anydata...;|}? result = check requests->findOne({"requestId": requestId});

    if result is record {|anydata...;|} {
        io:println("Tracking information found for request ", requestId);
    } else {
        io:println("No tracking information found for request ", requestId);
    }
}

// Process delivery confirmation
function processDeliveryConfirmation(string confirmationStr) returns error? {
    json confirmation = check value:fromJsonString(confirmationStr);
    string requestId = check confirmation.requestId;

    io:println("Processing Delivery Confirmation: ", requestId);

    mongodb:Database logistics = check mongoClient->getDatabase("logistics");
    mongodb:Collection requests = check logistics->getCollection("requests");

    mongodb:Update update = {
        "$set": {
            "status": check confirmation.status,
            "pickupTime": check confirmation.pickupTime,
            "estimatedDeliveryTime": check confirmation.estimatedDeliveryTime
        }
    };
    _ = check requests->updateOne({"requestId": requestId}, update);
}

// Forward request to appropriate service
function forwardToService(string topic, json request) returns error? {
    kafka:Producer kafkaProducer = check setupKafkaProducer();
    byte[] serializedMsg = request.toJsonString().toBytes();
    check kafkaProducer->send({ topic: topic, value: serializedMsg });
    check kafkaProducer->'flush();
    check kafkaProducer->'close();
}

// Setup Kafka producer
function setupKafkaProducer() returns kafka:Producer|error {
    kafka:ProducerConfiguration producerConfigs = {
        clientId: "logistics-service",
        acks: "all",
        retryCount: 3
    };
    return new (kafka:DEFAULT_URL, producerConfigs);
}

// Get all delivery requests from the database
function getDeliveryRequests() returns stream<record {}, error?>|error {
    mongodb:Database logisticsDb = check mongoClient->getDatabase("logistics");
    mongodb:Collection requests = check logisticsDb->getCollection("requests");
    return requests->find();
}

// Update delivery status in the database
function updateDeliveryStatus(string requestId, string status) returns error? {
    mongodb:Database logisticsDb = check mongoClient->getDatabase("logistics");
    mongodb:Collection requests = check logisticsDb->getCollection("requests");
    mongodb:Update update = {
        "$set": {
            "status": status
        }
    };
    _ = check requests->updateOne({"requestId": requestId}, update);
    io:println("Delivery status updated for request ", requestId, ": ", status);
}
// Custom error types for better error handling
type DeliveryRequestError distinct error<record {|string message;|}>;
type TrackingRequestError distinct error<record {|string message;|}>;
type DeliveryConfirmationError distinct error<record {|string message;|}>;
