/// Demo.Postgres.Operation - Business Operation for PostgreSQL database insertions
Class Demo.Postgres.Operation Extends Ens.BusinessOperation
{

/// Adapter type for SQL operations
Parameter ADAPTER = "EnsLib.SQL.OutboundAdapter";
/// Simple ODBC connection test using a temporary adapter instance
ClassMethod TestConnection() As %Status
{
    Set sc = $$$OK
    Try {
        Set adapter = ##class(EnsLib.SQL.OutboundAdapter).%New()
        Set adapter.DSN = "PostgreSQL-Demo"
        // Credentials are embedded in DSN, no need to set separately
        Do adapter.Connect()
        Do ##class(Demo.Util.Logger).WriteEvent("INFO","Demo.Postgres.Operation","ODBC connect OK to DSN PostgreSQL-Demo")
        Do adapter.Disconnect()
    } Catch ex {
        Set sc = ex.AsStatus()
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR","Demo.Postgres.Operation","ODBC connect failed: " _ ex.DisplayString())
    }
    Quit sc
}

/// Batch size for bulk insertions
Property BatchSize As %Integer [ InitialExpression = 100 ];

/// Maximum retry attempts for failed connections
Property MaxRetries As %Integer [ InitialExpression = 3 ];

/// Connection retry delay (seconds)
Property RetryDelay As %Integer [ InitialExpression = 5 ];

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
        Set pResponse.DatabaseType = "PostgreSQL"
        Set pResponse.RequestId = pRequest.RequestId
        Set pResponse.TotalRecords = pRequest.TotalRecords
        Set pResponse.RecordsInserted = 0
        Set pResponse.RecordsFailed = 0
        Set pResponse.ProcessedAt = ##class(Demo.Util.Logger).NowISO()
        Set pResponse.Status = "processing"
        
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.Postgres.Operation", "Starting PostgreSQL insertion for " _ pRequest.TotalRecords _ " records")
        
        // Validate request
        If pRequest.TotalRecords = 0 {
            Set pResponse.Status = "ok"
            Set pResponse.ErrorMessage = "No records to process"
            Return $$$OK
        }
        
        // Ensure database connection
        Set connStatus = ..EnsureConnection()
        If $$$ISERR(connStatus) {
            Set pResponse.Status = "error"
            Set pResponse.ErrorMessage = "Failed to establish PostgreSQL connection: " _ $System.Status.GetErrorText(connStatus)
            Set pResponse.RecordsFailed = pRequest.TotalRecords
            Return $$$OK
        }
        
        // Ensure table exists
        Set tableStatus = ..EnsureTableExists()
        If $$$ISERR(tableStatus) {
            Set pResponse.Status = "error"
            Set pResponse.ErrorMessage = "Failed to ensure table exists: " _ $System.Status.GetErrorText(tableStatus)
            Set pResponse.RecordsFailed = pRequest.TotalRecords
            Return $$$OK
        }
        
        // Process records in batches
        Set totalProcessed = 0
        Set batchNumber = 1
        
        While totalProcessed < pRequest.TotalRecords {
            Set batchStart = totalProcessed + 1
            Set batchEnd = batchStart + ..BatchSize - 1
            If batchEnd > pRequest.TotalRecords {
                Set batchEnd = pRequest.TotalRecords
            }
            
            Set batchStatus = ..ProcessBatch(pRequest, batchStart, batchEnd, batchNumber, .batchInserted, .batchFailed)
            
            Set totalProcessed = totalProcessed + (batchEnd - batchStart + 1)
            Set pResponse.RecordsInserted = pResponse.RecordsInserted + batchInserted
            Set pResponse.RecordsFailed = pResponse.RecordsFailed + batchFailed
            
            If $$$ISERR(batchStatus) {
                Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.Postgres.Operation", "Batch " _ batchNumber _ " failed: " _ $System.Status.GetErrorText(batchStatus))
            }
            
            Set batchNumber = batchNumber + 1
        }
        
        // Determine final status
        If pResponse.RecordsFailed = 0 {
            Set pResponse.Status = "ok"
        } ElseIf pResponse.RecordsInserted > 0 {
            Set pResponse.Status = "partial"
            Set pResponse.ErrorMessage = "Some records failed: " _ pResponse.RecordsFailed _ " of " _ pRequest.TotalRecords
        } Else {
            Set pResponse.Status = "failed"
            Set pResponse.ErrorMessage = "All records failed to insert"
        }
        
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.Postgres.Operation", "PostgreSQL insertion completed: " _ pResponse.RecordsInserted _ " inserted, " _ pResponse.RecordsFailed _ " failed")
        
    } Catch ex {
        Set status = ex.AsStatus()
        Set pResponse.Status = "error"
        Set pResponse.ErrorMessage = "PostgreSQL operation exception: " _ ex.DisplayString()
        Set pResponse.RecordsFailed = pRequest.TotalRecords
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.Postgres.Operation", "Exception during PostgreSQL operation: " _ ex.DisplayString())
    }
    
    Return $$$OK
}

/// Process a batch of records
Method ProcessBatch(pRequest As Demo.Msg.DatabaseInsertRequest, batchStart As %Integer, batchEnd As %Integer, batchNumber As %Integer, Output recordsInserted As %Integer, Output recordsFailed As %Integer) As %Status
{
    Set status = $$$OK
    Set recordsInserted = 0
    Set recordsFailed = 0
    
    Try {
        Set batchSize = batchEnd - batchStart + 1
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.Postgres.Operation", "Processing batch " _ batchNumber _ " (records " _ batchStart _ "-" _ batchEnd _ ")")
        
        // Start transaction for batch
        Set transactionStarted = 0
        Try {
            Do ..Adapter.ExecuteUpdate("BEGIN")
            Set transactionStarted = 1
        } Catch ex {
            Do ##class(Demo.Util.Logger).WriteEvent("WARNING", "Demo.Postgres.Operation", "Could not start transaction: " _ ex.DisplayString())
        }
        
        // Prepare batch insert statement
        Set insertSQL = "INSERT INTO demo_data (name, value, email, created_at, file_hash) VALUES "
        Set valuesParts = ""
        
        For i=batchStart:1:batchEnd {
            If pRequest.CSVRecords.IsDefined(i) {
                Set csvLine = pRequest.CSVRecords.GetAt(i)
                Set parsedData = ..ParseCSVLine(csvLine, i)
                
                If parsedData.IsValid {
                    If valuesParts '= "" Set valuesParts = valuesParts _ ", "
                    Set valuesParts = valuesParts _ "(" _ parsedData.SQLValues _ ")"
                } Else {
                    Set recordsFailed = recordsFailed + 1
                    Do ##class(Demo.Util.Logger).WriteEvent("WARNING", "Demo.Postgres.Operation", "Invalid CSV line " _ i _ ": " _ csvLine)
                }
            } Else {
                Set recordsFailed = recordsFailed + 1
                Do ##class(Demo.Util.Logger).WriteEvent("WARNING", "Demo.Postgres.Operation", "Missing CSV record " _ i)
            }
        }
        
        // Execute batch insert if we have valid records
        If valuesParts '= "" {
            Set fullSQL = insertSQL _ valuesParts
            
            Try {
                Set result = ..Adapter.ExecuteUpdate(fullSQL)
                Set recordsInserted = result
                
                If transactionStarted {
                    Do ..Adapter.ExecuteUpdate("COMMIT")
                }
                
                Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.Postgres.Operation", "Batch " _ batchNumber _ " inserted " _ recordsInserted _ " records")
                
            } Catch insertEx {
                If transactionStarted {
                    Try { Do ..Adapter.ExecuteUpdate("ROLLBACK") } Catch {}
                }
                
                // Fall back to individual inserts for this batch
                Do ##class(Demo.Util.Logger).WriteEvent("WARNING", "Demo.Postgres.Operation", "Batch insert failed, trying individual inserts: " _ insertEx.DisplayString())
                Set status = ..ProcessBatchIndividually(pRequest, batchStart, batchEnd, .recordsInserted, .recordsFailed)
            }
        } Else {
            // All records in batch were invalid
            Set recordsFailed = batchSize
            If transactionStarted {
                Try { Do ..Adapter.ExecuteUpdate("ROLLBACK") } Catch {}
            }
        }
        
    } Catch ex {
        Set status = ex.AsStatus()
        Set recordsFailed = batchEnd - batchStart + 1
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.Postgres.Operation", "Batch " _ batchNumber _ " processing failed: " _ ex.DisplayString())
        
        If transactionStarted {
            Try { Do ..Adapter.ExecuteUpdate("ROLLBACK") } Catch {}
        }
    }
    
    Return status
}

/// Process batch records individually (fallback)
Method ProcessBatchIndividually(pRequest As Demo.Msg.DatabaseInsertRequest, batchStart As %Integer, batchEnd As %Integer, Output recordsInserted As %Integer, Output recordsFailed As %Integer) As %Status
{
    Set status = $$$OK
    Set recordsInserted = 0
    Set recordsFailed = 0
    
    Try {
        Set insertSQL = "INSERT INTO demo_data (name, value, email, created_at, file_hash) VALUES ($1, $2, $3, NOW(), $4)"
        
        For i=batchStart:1:batchEnd {
            If pRequest.CSVRecords.IsDefined(i) {
                Set csvLine = pRequest.CSVRecords.GetAt(i)
                Set parsedData = ..ParseCSVLine(csvLine, i)
                
                If parsedData.IsValid {
                    Try {
                        Set result = ..Adapter.ExecuteUpdate(insertSQL, parsedData.Name, parsedData.Value, parsedData.Email, parsedData.FileHash)
                        Set recordsInserted = recordsInserted + 1
                    } Catch insertEx {
                        Set recordsFailed = recordsFailed + 1
                        Do ##class(Demo.Util.Logger).WriteEvent("WARNING", "Demo.Postgres.Operation", "Individual insert failed for record " _ i _ ": " _ insertEx.DisplayString())
                    }
                } Else {
                    Set recordsFailed = recordsFailed + 1
                }
            } Else {
                Set recordsFailed = recordsFailed + 1
            }
        }
        
    } Catch ex {
        Set status = ex.AsStatus()
        Set recordsFailed = batchEnd - batchStart + 1
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.Postgres.Operation", "Individual processing failed: " _ ex.DisplayString())
    }
    
    Return status
}

/// Parse CSV line into structured data
Method ParseCSVLine(csvLine As %String, lineNumber As %Integer) As %DynamicObject
{
    Set result = {}
    Set result.IsValid = 0
    
    Try {
        // Simple CSV parsing (could be enhanced for complex CSV with quotes, escapes)
        Set fields = $ListFromString(csvLine, ",")
        Set fieldCount = $ListLength(fields)
        
        If fieldCount < 3 {
            Set result.Error = "Insufficient fields (expected at least 3, got " _ fieldCount _ ")"
            Return result
        }
        
        // Extract and clean fields
        Set name = $ZStrip($List(fields, 1), "<>W""'")
        Set value = $ZStrip($List(fields, 2), "<>W""'")
        Set email = $ZStrip($List(fields, 3), "<>W""'")
        
        // Basic validation
        If name = "" {
            Set result.Error = "Name field is empty"
            Return result
        }
        
        If value = "" {
            Set result.Error = "Value field is empty"
            Return result
        }
        
        // Email validation (basic)
        If email '= "" && (email '[ "@" || email '[ ".") {
            Set result.Error = "Invalid email format"
            Return result
        }
        
        // Create file hash from line content for tracking
        Set fileHash = ##class(Demo.Util.Logger).HashString(csvLine)
        
        // Set result data
        Set result.IsValid = 1
        Set result.Name = name
        Set result.Value = value
        Set result.Email = email
        Set result.FileHash = fileHash
        Set result.SQLValues = "'" _ ..EscapeSQL(name) _ "', '" _ ..EscapeSQL(value) _ "', '" _ ..EscapeSQL(email) _ "', NOW(), '" _ fileHash _ "'"
        
    } Catch ex {
        Set result.Error = "Parsing exception: " _ ex.DisplayString()
    }
    
    Return result
}

/// Escape SQL string values for PostgreSQL
Method EscapeSQL(value As %String) As %String
{
    Set escaped = $Replace(value, "'", "''")
    Set escaped = $Replace(escaped, "\", "\\")
    Return escaped
}

/// Ensure database connection is available
Method EnsureConnection() As %Status
{
    Set status = $$$OK
    Set retryCount = 0
    
    While retryCount < ..MaxRetries {
        Try {
            // Test connection with simple query
            Set result = ..Adapter.ExecuteQuery("SELECT 1 as test")
            If $IsObject(result) {
                Do result.Close()
                Return $$$OK
            }
        } Catch ex {
            Set retryCount = retryCount + 1
            Do ##class(Demo.Util.Logger).WriteEvent("WARNING", "Demo.Postgres.Operation", "Connection test failed (attempt " _ retryCount _ "): " _ ex.DisplayString())
            
            If retryCount < ..MaxRetries {
                Hang ..RetryDelay
                Try {
                    // Try to reconnect
                    Do ..Adapter.Disconnect()
                    Do ..Adapter.Connect()
                } Catch connectEx {
                    Do ##class(Demo.Util.Logger).WriteEvent("WARNING", "Demo.Postgres.Operation", "Reconnection failed: " _ connectEx.DisplayString())
                }
            }
        }
    }
    
    Return $$$ERROR(5001, "Failed to establish PostgreSQL connection after " _ ..MaxRetries _ " attempts")
}

/// Ensure demo_data table exists
Method EnsureTableExists() As %Status
{
    Set status = $$$OK
    
    Try {
        // Check if table exists
        Set checkSQL = "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'demo_data')"
        Set result = ..Adapter.ExecuteQuery(checkSQL)
        
        Set tableExists = 0
        If $IsObject(result) {
            If result.Next() {
                Set exists = result.Get("exists")
                If exists = 1 || exists = "t" || exists = "true" {
                    Set tableExists = 1
                }
            }
            Do result.Close()
        }
        
        If 'tableExists {
            // Create table
            Set createSQL = "CREATE TABLE demo_data ("
            Set createSQL = createSQL _ "id SERIAL PRIMARY KEY, "
            Set createSQL = createSQL _ "name VARCHAR(255) NOT NULL, "
            Set createSQL = createSQL _ "value VARCHAR(255) NOT NULL, "
            Set createSQL = createSQL _ "email VARCHAR(255), "
            Set createSQL = createSQL _ "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
            Set createSQL = createSQL _ "file_hash VARCHAR(64)"
            Set createSQL = createSQL _ ")"
            
            Do ..Adapter.ExecuteUpdate(createSQL)
            
            // Create indexes
            Do ..Adapter.ExecuteUpdate("CREATE INDEX idx_demo_data_file_hash ON demo_data(file_hash)")
            Do ..Adapter.ExecuteUpdate("CREATE INDEX idx_demo_data_created_at ON demo_data(created_at)")
            
            Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.Postgres.Operation", "Created demo_data table in PostgreSQL")
        }
        
    } Catch ex {
        Set status = ex.AsStatus()
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.Postgres.Operation", "Error ensuring table exists: " _ ex.DisplayString())
    }
    
    Return status
}

}