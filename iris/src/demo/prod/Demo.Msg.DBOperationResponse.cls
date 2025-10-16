/// Demo.Msg.DBOperationResponse - Response message from database operations
Class Demo.Msg.DBOperationResponse Extends Ens.Response
{

/// Number of records successfully processed
Property RecordsOK As %Integer;

/// Number of records that failed
Property RecordsFailed As %Integer;

/// Array of error messages for failed records
Property FailedRecordErrors As list Of %String(MAXLEN = 500);

/// Overall operation status
Property Status As %String(MAXLEN = 20);

/// Error message if operation failed completely
Property ErrorMessage As %String(MAXLEN = 2000);

/// Method to add error for failed record
Method AddFailedRecordError(recordIndex As %Integer, error As %String)
{
    Set errorMsg = "Record " _ recordIndex _ ": " _ error
    Do ..FailedRecordErrors.Insert(errorMsg)
}

/// Storage definition  
Storage Default
{
<Data name="DBOperationResponseDefaultData">
<Subscript>"DBOperationResponse"</Subscript>
<Value name="1">
<Value>RecordsOK</Value>
</Value>
<Value name="2">
<Value>RecordsFailed</Value>
</Value>
<Value name="3">
<Value>FailedRecordErrors</Value>
</Value>
<Value name="4">
<Value>Status</Value>
</Value>
<Value name="5">
<Value>ErrorMessage</Value>
</Value>
</Data>
<DataLocation>^Ens.MessageBodyD</DataLocation>
<DefaultData>DBOperationResponseDefaultData</DefaultData>
<IdLocation>^Ens.MessageBodyD</IdLocation>
<IndexLocation>^Ens.MessageBodyI</IndexLocation>
<StreamLocation>^Ens.MessageBodyS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}