/// Demo.Msg.FileProcessResponse - Response message for file processing
Class Demo.Msg.FileProcessResponse Extends Ens.Response
{

/// Overall processing status: "ok", "partial", "failed", "error"
Property Status As %String(MAXLEN = 20) [ Required ];

/// Total number of records found in CSV file
Property TotalRecords As %Integer [ InitialExpression = 0 ];

/// Number of records successfully processed by MySQL
Property MySQLRecordsOK As %Integer [ InitialExpression = 0 ];

/// Number of records that failed in MySQL
Property MySQLRecordsFailed As %Integer [ InitialExpression = 0 ];

/// Number of records successfully processed by PostgreSQL
Property PostgreSQLRecordsOK As %Integer [ InitialExpression = 0 ];

/// Number of records that failed in PostgreSQL
Property PostgreSQLRecordsFailed As %Integer [ InitialExpression = 0 ];

/// Error message if status is "error" or "failed"
Property ErrorMessage As %String(MAXLEN = 2000);

/// Original filename for tracking
Property FileName As %String(MAXLEN = 255);

/// File hash for tracking
Property FileHash As %String(MAXLEN = 64);

/// Timestamp when processing was completed
Property ProcessedAt As %TimeStamp;

/// Processing duration in seconds
Property ProcessingDuration As %Numeric;

/// Method to calculate total success count
Method GetTotalSuccessCount() As %Integer
{
    Return ..MySQLRecordsOK + ..PostgreSQLRecordsOK
}

/// Method to calculate total failure count
Method GetTotalFailureCount() As %Integer
{
    Return ..MySQLRecordsFailed + ..PostgreSQLRecordsFailed
}

/// Method to get success rate percentage
Method GetSuccessRate() As %Numeric
{
    Set totalExpected = ..TotalRecords * 2  // Expected in both databases
    If totalExpected = 0 Return 0
    Return (..GetTotalSuccessCount() / totalExpected) * 100
}

/// Storage definition
Storage Default
{
<Data name="FileProcessResponseDefaultData">
<Subscript>"FileProcessResponse"</Subscript>
<Value name="1">
<Value>Status</Value>
</Value>
<Value name="2">
<Value>TotalRecords</Value>
</Value>
<Value name="3">
<Value>MySQLRecordsOK</Value>
</Value>
<Value name="4">
<Value>MySQLRecordsFailed</Value>
</Value>
<Value name="5">
<Value>PostgreSQLRecordsOK</Value>
</Value>
<Value name="6">
<Value>PostgreSQLRecordsFailed</Value>
</Value>
<Value name="7">
<Value>ErrorMessage</Value>
</Value>
<Value name="8">
<Value>FileName</Value>
</Value>
<Value name="9">
<Value>FileHash</Value>
</Value>
<Value name="10">
<Value>ProcessedAt</Value>
</Value>
<Value name="11">
<Value>ProcessingDuration</Value>
</Value>
</Data>
<DataLocation>^Ens.MessageBodyD</DataLocation>
<DefaultData>FileProcessResponseDefaultData</DefaultData>
<IdLocation>^Ens.MessageBodyD</IdLocation>
<IndexLocation>^Ens.MessageBodyI</IndexLocation>
<StreamLocation>^Ens.MessageBodyS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}