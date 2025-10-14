/// Demo.MySQL.Operation - Business Operation for MySQL database insertions (JDBC version)
Class Demo.MySQL.Operation Extends Ens.BusinessOperation
{

/// No adapter - using direct JDBC connection
Parameter ADAPTER = "";

/// JDBC Connection URL
Property JDBCURL As %String [ InitialExpression = "jdbc:mysql://localhost:3306/demo" ];

/// MySQL credentials ID
Property Credentials As %String [ InitialExpression = "MySQL-Demo-Credentials" ];

/// Batch size for bulk insertions
Property BatchSize As %Integer [ InitialExpression = 100 ];

/// Handle database operation requests
Method OnMessage(pRequest As Demo.Msg.DatabaseInsertRequest, Output pResponse As Demo.Msg.DatabaseInsertResponse) As %Status
{
    Return ..ProcessDatabaseInsert(pRequest, .pResponse)
}

/// Process database insert request
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
        
        // Create JDBC connection
        Set connStatus = ..CreateConnection(.connection)
        If $$$ISERR(connStatus) {
            Set pResponse.Status = "error"
            Set pResponse.ErrorMessage = "Failed to establish MySQL connection: " _ $System.Status.GetErrorText(connStatus)
            Return connStatus
        }
        
        // Process records in batches
        Set totalInserted = 0
        Set totalFailed = 0
        
        For i=1:1:pRequest.TotalRecords {
            Set csvLine = pRequest.CSVLines.GetAt(i)
            If csvLine '= "" {
                Set insertStatus = ..InsertRecord(connection, csvLine, pRequest.SourceFile)
                If $$$ISOK(insertStatus) {
                    Set totalInserted = totalInserted + 1
                } Else {
                    Set totalFailed = totalFailed + 1
                }
            }
        }
        
        // Clean up connection
        Try { Do connection.Disconnect() } Catch {}
        
        Set pResponse.RecordsInserted = totalInserted
        Set pResponse.RecordsFailed = totalFailed
        Set pResponse.Status = "completed"
        
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.MySQL.Operation", "MySQL insertion completed: " _ totalInserted _ " inserted, " _ totalFailed _ " failed")
        
    } Catch ex {
        Set status = ex.AsStatus()
        Set pResponse.Status = "error"
        Set pResponse.ErrorMessage = "MySQL operation exception: " _ ex.DisplayString()
        
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.MySQL.Operation", "Exception during MySQL operation: " _ ex.DisplayString())
    }
    
    Return status
}

/// Create JDBC connection
Method CreateConnection(Output connection As %SQL.Gateway.Connection) As %Status
{
    Set status = $$$OK
    
    Try {
        // Get credentials
        Set credentials = ##class(Ens.Config.Credentials).GetCredentialsObj(..Credentials)
        If '$IsObject(credentials) {
            Return $$$ERROR($$$EnsErrGeneral, "Cannot find credentials: " _ ..Credentials)
        }
        
        // Create JDBC connection
        Set connection = ##class(%SQL.Gateway.Connection).%New()
        Set connection.URL = ..JDBCURL
        Set connection.ClassPath = "/usr/share/java/mysql-connector-java-8.0.28.jar"
        Set connection.Username = credentials.Username
        Set connection.Password = credentials.Password
        
        // Connect
        Set status = connection.Connect()
        If $$$ISERR(status) {
            Return status
        }
        
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.MySQL.Operation", "MySQL JDBC connection established")
        
    } Catch ex {
        Set status = ex.AsStatus()
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.MySQL.Operation", "Connection failed: " _ ex.DisplayString())
    }
    
    Return status
}

/// Insert a single record
Method InsertRecord(connection As %SQL.Gateway.Connection, csvLine As %String, sourceFile As %String) As %Status
{
    Set status = $$$OK
    
    Try {
        // Parse CSV line (expecting: id,name,age,city)
        Set fields = $ListFromString(csvLine, ",")
        If $ListLength(fields) < 4 {
            Return $$$ERROR($$$EnsErrGeneral, "Invalid CSV format")
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
            Return $$$ERROR($$$EnsErrGeneral, "Age must be numeric")
        }
        
        // Generate external_id from line content hash
        Set externalId = ##class(Demo.Util.Logger).HashString(csvLine)
        Set fileHash = ##class(Demo.Util.Logger).HashString(csvLine _ $ZDateTime($ZTimeStamp, 3))
        
        // Insert into records table
        Set sql = "INSERT INTO records (external_id, name, amount, created_at, source_file, file_hash) VALUES (?, ?, ?, NOW(), ?, ?)"
        Set rs = connection.PrepareStatement(sql)
        Do rs.setString(1, externalId)
        Do rs.setString(2, name)
        Do rs.setInt(3, +age)  // Use age as amount for now
        Do rs.setString(4, sourceFile)
        Do rs.setString(5, fileHash)
        
        Set result = rs.executeUpdate()
        Do rs.close()
        
        If result > 0 {
            Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.MySQL.Operation", "Record inserted: " _ name)
        }
        
    } Catch ex {
        Set status = ex.AsStatus()
        Do ##class(Demo.Util.Logger).WriteEvent("WARNING", "Demo.MySQL.Operation", "Failed to insert record: " _ ex.DisplayString())
    }
    
    Return status
}

/// Get operation statistics
Method GetStats() As %String
{
    Set stats = ""
    
    Try {
        Set stats = stats _ "Operation: Demo.MySQL.Operation (JDBC)" _ $C(13,10)
        Set stats = stats _ "JDBC URL: " _ ..JDBCURL _ $C(13,10)
        Set stats = stats _ "Credentials: " _ ..Credentials _ $C(13,10)
        Set stats = stats _ "Batch Size: " _ ..BatchSize _ $C(13,10)
        
    } Catch ex {
        Set stats = "Error getting stats: " _ ex.DisplayString()
    }
    
    Return stats
}

}