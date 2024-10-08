import ballerina/io;
import ballerinax/kafka;

public function main() {
    io:println("Welcome To Assignment 2 for DSA621S 2024");
}
type Customer record {
    string firstName;
    string lastName;
    string contactNumber;
};
type Shipment record {|
    string pickUpLocation;
    string deliveryLocaion;
    string prefferedTimeSlot;
    string customerName;
|};

kafka:ProducerConfiguration producerConfig = {
    clientId: "Logistics-producer",
    acks: "all"
};

kafka:Producer kafkaProducer = check new (kafka:DEFAULT_URL, producerConfig);

kafka:ConsumerConfiguration consumerConfiguration = {
    groupId: "group-id",
    topics: ["standard-logistics-servces"],
    pollingInterval: 1,
    autoCommit: false
};

