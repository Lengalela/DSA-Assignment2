import ballerinax/kafka;
import ballerina/lang.value;
import ballerina/log;

// Configurable variables
configurable string groupId = "international-delivery-group";
configurable string consumeTopic = "international-delivery";
configurable string produceTopic = "delivery-confirmations";

// The main function is marked as isolated for improved concurrency safety
public isolated function main() returns error? {
    kafka:Consumer kafkaConsumer = check createKafkaConsumer();
    log:printInfo("International delivery service started. Waiting for requests...");

    check startConsumerLoop(kafkaConsumer);
}

// Separate function for creating the Kafka consumer
isolated function createKafkaConsumer() returns kafka:Consumer|error {
    kafka:ConsumerConfiguration consumerConfigs = {
        groupId,
        topics: [consumeTopic],
        offsetReset: "earliest"
    };
    return new (kafka:DEFAULT_URL, consumerConfigs);
}

// Main consumer loop is now in its own function
isolated function startConsumerLoop(kafka:Consumer kafkaConsumer) returns error? {
    while true {
        kafka:AnydataConsumerRecord[] records = check kafkaConsumer->poll(1);
        check processRecords(records);
    }
}

// Separate function for processing records
isolated function processRecords(kafka:AnydataConsumerRecord[] records) returns error? {
    foreach kafka:AnydataConsumerRecord rec in records {
        string stringValue = check string:fromBytes(check rec.value.ensureType());
        check processInternationalDelivery(stringValue);
    }
}

// Process international delivery requests
isolated function processInternationalDelivery(string requestStr) returns error? {
    json request = check value:fromJsonString(requestStr);
    log:printInfo("Processing international delivery request: " + request.toJsonString());
    check sendConfirmation(request);
}

// Send confirmation for the delivery request
isolated function sendConfirmation(json request) returns error? {
    kafka:Producer kafkaProducer = check createKafkaProducer();
    json confirmation = check createConfirmationJson(request);
    check sendKafkaMessage(kafkaProducer, confirmation);
    check kafkaProducer->'close();
}

// Separate function for creating the Kafka producer
isolated function createKafkaProducer() returns kafka:Producer|error {
    kafka:ProducerConfiguration producerConfigs = {
        clientId: "international-delivery-service",
        acks: "all",
        retryCount: 3
    };
    return new (kafka:DEFAULT_URL, producerConfigs);
}

// Create the confirmation JSON
isolated function createConfirmationJson(json request) returns json|error {
    return {
        "requestId": check request.requestId,
        "status": "confirmed",
        "pickupTime": "2023-05-10T10:00:00Z",
        "estimatedDeliveryTime": "2023-05-15T14:00:00Z"  // Longer delivery time for international
    };
}

// Send the Kafka message
isolated function sendKafkaMessage(kafka:Producer producer, json message) returns error? {
    byte[] serializedMsg = message.toJsonString().toBytes();
    check producer->send({
        topic: produceTopic,
        value: serializedMsg
    });
    check producer->'flush();
}

