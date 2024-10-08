import ballerina/io;
import ballerinax/kafka;
import ballerina/log;

public function main() {
    io:println("Welcome To Assignment 2 for DSA621S");
}
type Shipment record {|
    string pickUpLocation;
    string deliveryLocaion;
    string prefferedTimeSlot;
    string customerName;
|};

kafka:ProducerConfiguration producerConfig={
    clientId: "Logistics-producer",
    acks: "all"
};

kafka:Producer kafkaProducer= check new(kafka:DEFAULT_URL,producerConfig);

public function sendShipmentRequest(Shipment shipment) returns error?{
    json shipmentJson _= shipment.toJson();
    check kafkaProducer->send({
        topic: "shipment-request",
        value:  shipmentJson.toString()
    });
    return ;
}