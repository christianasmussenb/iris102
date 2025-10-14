/// Demo.Msg.CSVRecord - Data class representing a CSV record
Class Demo.Msg.CSVRecord Extends (%SerialObject, %XML.Adaptor)
{

/// External ID from CSV
Property ExternalId As %String(MAXLEN = 64) [ Required ];

/// Name from CSV
Property Name As %String(MAXLEN = 200) [ Required ];

/// Amount from CSV
Property Amount As %Numeric(SCALE = 2) [ Required ];

/// Occurred timestamp from CSV
Property OccurredAt As %TimeStamp [ Required ];

/// Validation method
Method %OnValidateObject() As %Status
{
    Set status = $$$OK
    
    // Validate external ID is not empty
    If ..ExternalId = "" {
        Set status = $$$ADDSC(status, $$$ERROR(5001, "ExternalId cannot be empty"))
    }
    
    // Validate name is not empty
    If ..Name = "" {
        Set status = $$$ADDSC(status, $$$ERROR(5001, "Name cannot be empty"))
    }
    
    // Validate amount is positive
    If ..Amount <= 0 {
        Set status = $$$ADDSC(status, $$$ERROR(5001, "Amount must be positive"))
    }
    
    // Validate occurred_at is valid timestamp
    If ..OccurredAt = "" {
        Set status = $$$ADDSC(status, $$$ERROR(5001, "OccurredAt cannot be empty"))
    }
    
    Return status
}

/// Convert to display string
Method %DisplayString() As %String
{
    Return ..ExternalId _ " | " _ ..Name _ " | " _ ..Amount _ " | " _ ..OccurredAt
}

/// Storage definition
Storage Default
{
<Data name="CSVRecordState">
<Value name="1">
<Value>ExternalId</Value>
</Value>
<Value name="2">
<Value>Name</Value>
</Value>
<Value name="3">
<Value>Amount</Value>
</Value>
<Value name="4">
<Value>OccurredAt</Value>
</Value>
</Data>
<State>CSVRecordState</State>
<StreamLocation>^Demo.Msg.CSVRecordS</StreamLocation>
<Type>%Storage.Serial</Type>
}

}