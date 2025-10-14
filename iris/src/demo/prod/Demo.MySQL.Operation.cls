/// Demo.MySQL.Operation - Business Operation for MySQL database insertions
Class Demo.MySQL.Operation Extends Ens.BusinessOperation
{

/// Adapter type for SQL operations
Parameter ADAPTER = "EnsLib.SQL.OutboundAdapter";

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
        
        // Ensure database connection
        Set connStatus = ..EnsureConnection()
        If $$$ISERR(connStatus) {
            Set pResponse.Status = "error"
            Set pResponse.ErrorMessage = "Failed to establish MySQL connection: " _ $System.Status.GetErrorText(connStatus)
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
                Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.MySQL.Operation", "Batch " _ batchNumber _ " failed: " _ $System.Status.GetErrorText(batchStatus))
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
        
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.MySQL.Operation", "MySQL insertion completed: " _ pResponse.RecordsInserted _ " inserted, " _ pResponse.RecordsFailed _ " failed")
        
    } Catch ex {
        Set status = ex.AsStatus()
        Set pResponse.Status = "error"
        Set pResponse.ErrorMessage = "MySQL operation exception: " _ ex.DisplayString()
        Set pResponse.RecordsFailed = pRequest.TotalRecords
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.MySQL.Operation", "Exception during MySQL operation: " _ ex.DisplayString())
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
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.MySQL.Operation", "Processing batch " _ batchNumber _ " (records " _ batchStart _ "-" _ batchEnd _ ")")
        
        // Start transaction for batch
        Set transactionStarted = 0
        Try {
            Do ..Adapter.ExecuteUpdate("START TRANSACTION")
            Set transactionStarted = 1
        } Catch ex {
            Do ##class(Demo.Util.Logger).WriteEvent("WARNING", "Demo.MySQL.Operation", "Could not start transaction: " _ ex.DisplayString())
        }
        
        // Prepare batch insert statement for existing records table
        Set insertSQL = "INSERT INTO records (external_id, name, amount, occurred_at, source_file, file_hash) VALUES "
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
                    Do ##class(Demo.Util.Logger).WriteEvent("WARNING", "Demo.MySQL.Operation", "Invalid CSV line " _ i _ ": " _ csvLine)
                }
            } Else {
                Set recordsFailed = recordsFailed + 1
                Do ##class(Demo.Util.Logger).WriteEvent("WARNING", "Demo.MySQL.Operation", "Missing CSV record " _ i)
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
                
                Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.MySQL.Operation", "Batch " _ batchNumber _ " inserted " _ recordsInserted _ " records")
                
            } Catch insertEx {
                If transactionStarted {
                    Try { Do ..Adapter.ExecuteUpdate("ROLLBACK") } Catch {}
                }
                
                // Fall back to individual inserts for this batch
                Do ##class(Demo.Util.Logger).WriteEvent("WARNING", "Demo.MySQL.Operation", "Batch insert failed, trying individual inserts: " _ insertEx.DisplayString())
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
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.MySQL.Operation", "Batch " _ batchNumber _ " processing failed: " _ ex.DisplayString())
        
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
        Set insertSQL = "INSERT INTO records (external_id, name, amount, occurred_at, source_file, file_hash) VALUES (?, ?, ?, NOW(), ?, ?)"
        
        For i=batchStart:1:batchEnd {
            If pRequest.CSVRecords.IsDefined(i) {
                Set csvLine = pRequest.CSVRecords.GetAt(i)
                Set parsedData = ..ParseCSVLine(csvLine, i)
                
                If parsedData.IsValid {
                    Try {
                        Set result = ..Adapter.ExecuteUpdate(insertSQL, parsedData.ExternalId, parsedData.Name, parsedData.Amount, parsedData.SourceFile, parsedData.FileHash)
                        Set recordsInserted = recordsInserted + 1
                    } Catch insertEx {
                        Set recordsFailed = recordsFailed + 1
                        Do ##class(Demo.Util.Logger).WriteEvent("WARNING", "Demo.MySQL.Operation", "Individual insert failed for record " _ i _ ": " _ insertEx.DisplayString())
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
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.MySQL.Operation", "Individual processing failed: " _ ex.DisplayString())
    }
    
    Return status
}

/// Parse CSV line into structured data for records table
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
        
        // Extract and clean fields - mapping CSV to records table structure
        // CSV: name,value,email -> records: external_id, name, amount, occurred_at, source_file, file_hash
        Set name = $ZStrip($List(fields, 1), "<>W""'")
        Set amount = $ZStrip($List(fields, 2), "<>W""'")
        Set email = $ZStrip($List(fields, 3), "<>W""'")
        
        // Basic validation
        If name = "" {
            Set result.Error = "Name field is empty"
            Return result
        }
        
        If amount = "" {
            Set result.Error = "Amount field is empty"
            Return result
        }
        
        // Validate amount is numeric
        If '$IsValidNum(amount) {
            Set result.Error = "Amount field is not numeric: " _ amount
            Return result
        }
        
        // Generate external_id from line content hash for uniqueness
        Set externalId = ##class(Demo.Util.Logger).HashString(csvLine)
        
        // Create file hash from line content for tracking
        Set fileHash = ##class(Demo.Util.Logger).HashString(csvLine _ $ZDateTime($ZTimeStamp, 3))
        
        // Source file (will be set by calling process)
        Set sourceFile = "test_data.csv"  // Default for now
        
        // Set result data for records table
        Set result.IsValid = 1
        Set result.ExternalId = externalId
        Set result.Name = name
        Set result.Amount = +amount  // Convert to number
        Set result.Email = email  // Store in file_hash or ignore for now
        Set result.SourceFile = sourceFile
        Set result.FileHash = fileHash
        Set result.SQLValues = "'" _ ..EscapeSQL(externalId) _ "', '" _ ..EscapeSQL(name) _ "', " _ amount _ ", NOW(), '" _ ..EscapeSQL(sourceFile) _ "', '" _ fileHash _ "'"
        
    } Catch ex {
        Set result.Error = "Parsing exception: " _ ex.DisplayString()
    }
    
    Return result
}

/// Escape SQL string values
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
            Do ##class(Demo.Util.Logger).WriteEvent("WARNING", "Demo.MySQL.Operation", "Connection test failed (attempt " _ retryCount _ "): " _ ex.DisplayString())
            
            If retryCount < ..MaxRetries {
                Hang ..RetryDelay
                Try {
                    // Try to reconnect
                    Do ..Adapter.Disconnect()
                    Do ..Adapter.Connect()
                } Catch connectEx {
                    Do ##class(Demo.Util.Logger).WriteEvent("WARNING", "Demo.MySQL.Operation", "Reconnection failed: " _ connectEx.DisplayString())
                }
            }
        }
    }
    
    Return $$$ERROR(5001, "Failed to establish MySQL connection after " _ ..MaxRetries _ " attempts")
}

/// Ensure records table exists (verify existing table)
Method EnsureTableExists() As %Status
{
    Set status = $$$OK
    
    Try {
        // Check if records table exists
        Set checkSQL = "SHOW TABLES LIKE 'records'"
        Set result = ..Adapter.ExecuteQuery(checkSQL)
        
        Set tableExists = 0
        If $IsObject(result) {
            If result.Next() {
                Set tableExists = 1
            }
            Do result.Close()
        }
        
        If 'tableExists {
            Return $$$ERROR(5001, "Required table 'records' does not exist in MySQL database")
        }
        
        // Verify table structure has required columns
        Set describeSQL = "DESCRIBE records"
        Set result = ..Adapter.ExecuteQuery(describeSQL)
        Set requiredColumns = $ListBuild("external_id", "name", "amount", "occurred_at", "source_file", "file_hash")
        Set foundColumns = ""
        
        If $IsObject(result) {
            While result.Next() {
                Set columnName = result.Get("Field")
                Set foundColumns = foundColumns _ columnName _ ","
            }
            Do result.Close()
        }
        
        // Check that all required columns exist
        For i=1:1:$ListLength(requiredColumns) {
            Set requiredCol = $List(requiredColumns, i)
            If foundColumns '[ (requiredCol _ ",") {
                Return $$$ERROR(5001, "Required column '" _ requiredCol _ "' not found in records table")
            }
        }
        
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.MySQL.Operation", "Verified records table structure in MySQL")
        
    } Catch ex {
        Set status = ex.AsStatus()
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.MySQL.Operation", "Error verifying table structure: " _ ex.DisplayString())
    }
    
    Return status
}

/// Get operation statistics
Method GetStats() As %String
{
    Set stats = ""
    
    Try {
        Set stats = stats _ "Operation: Demo.MySQL.Operation" _ $C(13,10)
        Set stats = stats _ "Adapter: " _ ..%GetParameter("ADAPTER") _ $C(13,10)
        Set stats = stats _ "Batch Size: " _ ..BatchSize _ $C(13,10)
        Set stats = stats _ "Max Retries: " _ ..MaxRetries _ $C(13,10)
        Set stats = stats _ "Retry Delay: " _ ..RetryDelay _ "s" _ $C(13,10)
        
        // Try to get connection status
        Try {
            Set result = ..Adapter.ExecuteQuery("SELECT COUNT(*) as record_count FROM records")
            If $IsObject(result) && result.Next() {
                Set stats = stats _ "Total Records: " _ result.Get("record_count") _ $C(13,10)
                Do result.Close()
            }
        } Catch {
            Set stats = stats _ "Connection Status: Error" _ $C(13,10)
        }
        
    } Catch ex {
        Set stats = "Error getting stats: " _ ex.DisplayString()
    }
    
    Return stats
}

}