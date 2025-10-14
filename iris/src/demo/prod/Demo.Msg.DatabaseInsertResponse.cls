/// Demo.Msg.DatabaseInsertResponse - Response message for database insertions
Class Demo.Msg.DatabaseInsertResponse Extends Ens.Response
{

/// Database type that processed the request
Property DatabaseType As %String(MAXLEN = 50) [ Required ];

/// Request identifier for tracking
Property RequestId As %String(MAXLEN = 64) [ Required ];

/// Total number of records in the original request
Property TotalRecords As %Integer [ Required ];

/// Number of records successfully inserted
Property RecordsInserted As %Integer [ InitialExpression = 0 ];

/// Number of records that failed to insert
Property RecordsFailed As %Integer [ InitialExpression = 0 ];

/// Overall status: "ok", "partial", "failed", "error"
Property Status As %String(MAXLEN = 20) [ Required ];

/// Error message if status is "error" or "failed"
Property ErrorMessage As %String(MAXLEN = 2000);

/// Timestamp when processing was completed
Property ProcessedAt As %TimeStamp [ Required ];

/// Processing duration in seconds (calculated)
Property ProcessingDuration As %Numeric;

/// Method to calculate success rate
Method GetSuccessRate() As %Numeric
{
    If ..TotalRecords = 0 Return 0
    Return (..RecordsInserted / ..TotalRecords) * 100
}

/// Method to get a summary string
Method GetSummary() As %String
{
    Set summary = ..DatabaseType _ " insertion: "
    Set summary = summary _ ..RecordsInserted _ "/" _ ..TotalRecords _ " records inserted"
    
    If ..RecordsFailed > 0 {
        Set summary = summary _ " (" _ ..RecordsFailed _ " failed)"
    }
    
    Set summary = summary _ " - Status: " _ ..Status
    
    If ..ProcessingDuration '= "" {
        Set summary = summary _ " - Duration: " _ ..ProcessingDuration _ "s"
    }
    
    Return summary
}

/// Storage definition
Storage Default
{
<Data name="DatabaseInsertResponseDefaultData">
<Subscript>"DatabaseInsertResponse"</Subscript>
<Value name="1">
<Value>DatabaseType</Value>
</Value>
<Value name="2">
<Value>RequestId</Value>
</Value>
<Value name="3">
<Value>TotalRecords</Value>
</Value>
<Value name="4">
<Value>RecordsInserted</Value>
</Value>
<Value name="5">
<Value>RecordsFailed</Value>
</Value>
<Value name="6">
<Value>Status</Value>
</Value>
<Value name="7">
<Value>ErrorMessage</Value>
</Value>
<Value name="8">
<Value>ProcessedAt</Value>
</Value>
<Value name="9">
<Value>ProcessingDuration</Value>
</Value>
</Data>
<DataLocation>^Ens.MessageBodyD</DataLocation>
<DefaultData>DatabaseInsertResponseDefaultData</DefaultData>
<IdLocation>^Ens.MessageBodyD</IdLocation>
<IndexLocation>^Ens.MessageBodyI</IndexLocation>
<StreamLocation>^Ens.MessageBodyS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}