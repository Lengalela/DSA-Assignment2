import ballerina/io;
import ballerinax/kafka;
import ballerina/uuid;



public function main() returns error? {
    io:println("Welcome to the Logistics System");
    check runMainMenu();
}

function runMainMenu() returns error? {
    while (true) {
        displayMainMenu();
        int option = check getMenuOption();
        check handleMenuOption(option);
    }
}

function displayMainMenu() {
    io:println("\nPlease select an option:");
    io:println("1. Submit a new delivery request");
    io:println("2. Track a shipment");
    io:println("3. Exit");
}

function getMenuOption() returns int|error {
    return int:fromString(io:readln("Enter your choice (1-3): "));
}

function handleMenuOption(int option) returns error? {
    match option {
        1 => {
            check submitDeliveryRequest();
        }
        2 => {
            check trackShipment();
        }
        3 => {
            io:println("Thank you for using the Logistics System. Goodbye!");
            return error("Exit");
        }
        _ => {
            io:println("Invalid option. Please try again.");
        }
    }
}

function submitDeliveryRequest() returns error? {
    io:println("\nSubmitting a new delivery request");
    string shipmentType = check getShipmentType();
    json payload = collectDeliveryDetails(shipmentType);
    check sendToKafka(payload);
    displaySubmissionConfirmation((check payload.requestId).toString());
}

function getShipmentType() returns string|error {
    io:println("\nSelect shipment type:");
    io:println("1. Standard");
    io:println("2. Express");
    io:println("3. International");

    int shipmentChoice = check int:fromString(io:readln("Enter your choice (1-3): "));
    match shipmentChoice {
        1 => { return "standard"; }
        2 => { return "express"; }
        3 => { return "international"; }
        _ => {
            io:println("Invalid choice. Defaulting to standard shipment.");
            return "standard";
        }
    }
}

function collectDeliveryDetails(string shipmentType) returns json {
    string requestId = uuid:createType1AsString();
    return {
        "requestId": requestId,
        "shipmentType": shipmentType,
        "pickupLocation": io:readln("Enter pickup location: "),
        "deliveryLocation": io:readln("Enter delivery location: "),
        "preferredPickupTime": io:readln("Enter preferred pickup time (YYYY-MM-DD HH:MM): "),
        "preferredDeliveryTime": io:readln("Enter preferred delivery time (YYYY-MM-DD HH:MM): "),
        "firstName": io:readln("Enter first name: "),
        "lastName": io:readln("Enter last name: "),
        "contactNumber": io:readln("Enter contact number: ")
    };
}

function displaySubmissionConfirmation(string requestId) {
    io:println("Delivery request submitted successfully!");
    io:println("Your tracking number is: " + requestId);
    io:println("You can use this tracking number to check the status of your shipment.");
}

function trackShipment() returns error? {
    string trackingNumber = io:readln("Enter tracking number: ");
    json trackingRequest = { "requestId": trackingNumber };
    check sendToKafka(trackingRequest, "tracking-requests");
    displayTrackingConfirmation(trackingNumber);
}

function displayTrackingConfirmation(string trackingNumber) {
    io:println("Tracking information for " + trackingNumber + " has been requested.");
    io:println("Please check back later for updates on your shipment.");
}

function sendToKafka(json payload, string topic = "delivery-requests") returns error? {
    kafka:ProducerConfiguration producerConfigs = {
        clientId: "logistics-client",
        acks: "all",
        retryCount: 3
    };
    kafka:Producer kafkaProducer = check new (kafka:DEFAULT_URL, producerConfigs);
    byte[] serializedMsg = payload.toJsonString().toBytes();
    kafka:BytesProducerRecord producerRecord = {
        topic: topic,
        value: serializedMsg
    };
    check kafkaProducer->send(producerRecord);
    check kafkaProducer->'flush();
    check kafkaProducer->'close();
}
