/// Demo.MySQL.Operation - Business Operation for MySQL database insertions (Simple version)
Class Demo.MySQL.Operation Extends Ens.BusinessOperation
{

/// No adapter needed
Parameter ADAPTER = "";

/// MySQL Connection Settings
Property MySQLHost As %String [ InitialExpression = "localhost" ];

Property MySQLPort As %String [ InitialExpression = "3306" ];

Property MySQLDatabase As %String [ InitialExpression = "demo" ];

Property MySQLCredentials As %String [ InitialExpression = "MySQL-Demo-Credentials" ];

/// Handle database operation requests
Method OnMessage(pRequest As Demo.Msg.DatabaseInsertRequest, Output pResponse As Demo.Msg.DatabaseInsertResponse) As %Status
{
    Return ..ProcessDatabaseInsert(pRequest, .pResponse)
}

/// Process database insert request (simplified version)
Method ProcessDatabaseInsert(pRequest As Demo.Msg.DatabaseInsertRequest, Output pResponse As Demo.Msg.DatabaseInsertResponse) As %Status
{
    Set status = $$$OK
    Set pResponse = ##class(Demo.Msg.DatabaseInsertResponse).%New()
    
    Try {
        // Initialize response
        Set pResponse.DatabaseType = "MySQL"
        Set pResponse.RequestId = pRequest.RequestId
        Set pResponse.TotalRecords = pRequest.TotalRecords
        Set pResponse.RecordsInserted = 0
        Set pResponse.RecordsFailed = 0
        Set pResponse.ProcessedAt = ##class(Demo.Util.Logger).NowISO()
        Set pResponse.Status = "processing"
        
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.MySQL.Operation", "Starting MySQL insertion for " _ pRequest.TotalRecords _ " records")
        
        // Validate request
        If pRequest.TotalRecords = 0 {
            Set pResponse.Status = "ok"
            Set pResponse.ErrorMessage = "No records to process"
            Return $$$OK
        }
        
        // Process records (simulate successful processing for now)
        Set totalInserted = 0
        Set totalFailed = 0
        
        For i=1:1:pRequest.TotalRecords {
            Set csvLine = pRequest.CSVLines.GetAt(i)
            If csvLine '= "" {
                // Simulate record processing
                Set parseStatus = ..ParseCSVLine(csvLine)
                If $$$ISOK(parseStatus) {
                    Set totalInserted = totalInserted + 1
                    Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.MySQL.Operation", "Processed record " _ i _ ": " _ csvLine)
                } Else {
                    Set totalFailed = totalFailed + 1
                    Do ##class(Demo.Util.Logger).WriteEvent("WARNING", "Demo.MySQL.Operation", "Failed to parse record " _ i _ ": " _ csvLine)
                }
            }
        }
        
        Set pResponse.RecordsInserted = totalInserted
        Set pResponse.RecordsFailed = totalFailed
        Set pResponse.Status = "completed"
        
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.MySQL.Operation", "MySQL operation completed: " _ totalInserted _ " processed, " _ totalFailed _ " failed")
        
    } Catch ex {
        Set status = ex.AsStatus()
        Set pResponse.Status = "error"
        Set pResponse.ErrorMessage = "MySQL operation exception: " _ ex.DisplayString()
        
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.MySQL.Operation", "Exception during MySQL operation: " _ ex.DisplayString())
    }
    
    Return status
}

/// Parse CSV line (basic validation)
Method ParseCSVLine(csvLine As %String) As %Status
{
    Set status = $$$OK
    
    Try {
        // Parse CSV line (expecting: id,name,age,city)
        Set fields = $ListFromString(csvLine, ",")
        If $ListLength(fields) < 4 {
            Return $$$ERROR($$$EnsErrGeneral, "Invalid CSV format - expected 4 fields")
        }
        
        Set id = $ZStrip($List(fields, 1), "<>W""'")
        Set name = $ZStrip($List(fields, 2), "<>W""'")
        Set age = $ZStrip($List(fields, 3), "<>W""'")
        Set city = $ZStrip($List(fields, 4), "<>W""'")
        
        // Validate required fields
        If (id = "") || (name = "") || (age = "") {
            Return $$$ERROR($$$EnsErrGeneral, "Missing required fields")
        }
        
        // Validate age is numeric
        If '$IsValidNum(age) {
            Return $$$ERROR($$$EnsErrGeneral, "Age must be numeric: " _ age)
        }
        
        // If we get here, parsing was successful
        
    } Catch ex {
        Set status = ex.AsStatus()
    }
    
    Return status
}

/// Test MySQL connection (placeholder)
Method TestConnection() As %Status
{
    Set status = $$$OK
    
    Try {
        // Get credentials
        Set credentials = ##class(Ens.Config.Credentials).GetCredentialsObj(..MySQLCredentials)
        If '$IsObject(credentials) {
            Return $$$ERROR($$$EnsErrGeneral, "Cannot find credentials: " _ ..MySQLCredentials)
        }
        
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.MySQL.Operation", "MySQL connection test - credentials found for user: " _ credentials.Username)
        
        // For now, just simulate successful connection
        // In a real implementation, this would test the actual MySQL connection
        
    } Catch ex {
        Set status = ex.AsStatus()
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.MySQL.Operation", "Connection test failed: " _ ex.DisplayString())
    }
    
    Return status
}

/// Get operation statistics
Method GetStats() As %String
{
    Set stats = ""
    
    Try {
        Set stats = stats _ "Operation: Demo.MySQL.Operation (Simple)" _ $C(13,10)
        Set stats = stats _ "MySQL Host: " _ ..MySQLHost _ ":" _ ..MySQLPort _ $C(13,10)
        Set stats = stats _ "MySQL Database: " _ ..MySQLDatabase _ $C(13,10)
        Set stats = stats _ "Credentials: " _ ..MySQLCredentials _ $C(13,10)
        
    } Catch ex {
        Set stats = "Error getting stats: " _ ex.DisplayString()
    }
    
    Return stats
}

}