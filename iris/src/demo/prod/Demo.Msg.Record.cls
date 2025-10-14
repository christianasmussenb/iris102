/// Demo.Msg.FileProcessRequest - Request message for CSV file processing
Class Demo.Msg.FileProcessRequest Extends Ens.Request
{

/// Full path to the CSV file to process
Property FilePath As %String(MAXLEN = 500) [ Required ];

/// Original filename without path
Property FileName As %String(MAXLEN = 255) [ Required ];

/// File size in bytes  
Property FileSize As %Integer [ Required ];

/// SHA256 hash of the file content for duplicate detection
Property FileHash As %String(MAXLEN = 64) [ Required ];

/// Timestamp when file was detected
Property DetectedAt As %TimeStamp [ Required ];

/// Number of retry attempts (for error handling)
Property RetryCount As %Integer [ InitialExpression = 0 ];

/// Storage definition
Storage Default
{
<Data name="FileProcessRequestDefaultData">
<Subscript>"FileProcessRequest"</Subscript>
<Value name="1">
<Value>FilePath</Value>
</Value>
<Value name="2">
<Value>FileName</Value>
</Value>
<Value name="3">
<Value>FileSize</Value>
</Value>
<Value name="4">
<Value>FileHash</Value>
</Value>
<Value name="5">
<Value>DetectedAt</Value>
</Value>
<Value name="6">
<Value>RetryCount</Value>
</Value>
</Data>
<DataLocation>^Demo.Msg.FileProcessRequestD</DataLocation>
<DefaultData>FileProcessRequestDefaultData</DefaultData>
<IdLocation>^Demo.Msg.FileProcessRequestD</IdLocation>
<IndexLocation>^Demo.Msg.FileProcessRequestI</IndexLocation>
<StreamLocation>^Demo.Msg.FileProcessRequestS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}