import ballerina/lang.value;
import ballerina/log;
import ballerinax/kafka;

configurable string groupId = "standard-delivery-group";
configurable string consumeTopic = "standard-delivery";
configurable string produceTopic = "delivery-confirmations";

public function main() returns error? {
    kafka:Consumer kafkaConsumer = check createKafkaConsumer();
    log:printInfo("Standard delivery service started. Waiting for requests...");

    check startConsumerLoop(kafkaConsumer);
}

function createKafkaConsumer() returns kafka:Consumer|error {
    kafka:ConsumerConfiguration consumerConfigs = {
        groupId: groupId,
        topics: [consumeTopic],
        pollingInterval: 1,
        offsetReset: "earliest"
    };
    return new (kafka:DEFAULT_URL, consumerConfigs);
}

function startConsumerLoop(kafka:Consumer kafkaConsumer) returns error? {
    while true {
        kafka:AnydataConsumerRecord[] records = check kafkaConsumer->poll(1);
        check processRecords(records);
    }
}

function processRecords(kafka:AnydataConsumerRecord[] records) returns error? {
    foreach kafka:AnydataConsumerRecord rec in records {
        string stringValue = check string:fromBytes(check rec.value.ensureType());
        check processStandardDelivery(stringValue);
    }
}

function processStandardDelivery(string requestStr) returns error? {
    json request = check value:fromJsonString(requestStr);
    log:printInfo("Processing standard delivery request: " + request.toJsonString());
    check sendConfirmation(request);
}

function sendConfirmation(json request) returns error? {
    kafka:Producer kafkaProducer = check createKafkaProducer();
    json confirmation = check createConfirmationJson(request);
    check sendKafkaMessage(kafkaProducer, confirmation);
    check kafkaProducer->'close();
}

function createKafkaProducer() returns kafka:Producer|error {
    kafka:ProducerConfiguration producerConfigs = {
        clientId: "standard-delivery-service",
        acks: "all",
        retryCount: 3
    };
    return new (kafka:DEFAULT_URL, producerConfigs);
}

function createConfirmationJson(json request) returns json|error {
    return {
        "requestId": check request.requestId,
        "status": "confirmed",
        "pickupTime": "2023-05-10T10:00:00Z",
        "estimatedDeliveryTime": "2023-05-12T14:00:00Z"
    };
}

function sendKafkaMessage(kafka:Producer producer, json message) returns error? {
    byte[] serializedMsg = message.toJsonString().toBytes();
    check producer->send({
        topic: produceTopic,
        value: serializedMsg
    });
    check producer->'flush();
}
