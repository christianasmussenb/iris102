Include Ensemble

Class Demo.Postgres.JDBCOperation Extends Ens.BusinessOperation
{

Parameter ADAPTER = "EnsLib.SQL.OutboundAdapter";

Property Adapter As EnsLib.SQL.OutboundAdapter;

Parameter SETTINGS = "DSN:Basic:selector?context={Ens.ContextSearch/SQLConnections},JGService:Basic:selector?context={Ens.ContextSearch/JavaGateways}";

/// Nombre de la conexión SQL Gateway JDBC
Property DSN As %String [ InitialExpression = "PostgreSQL-Demo-JDBC" ];

/// Java Gateway Service para JDBC
Property JGService As %String [ InitialExpression = "%Java Server" ];

Method Insert(pRequest As Demo.Msg.DatabaseInsertRequest, Output pResponse As Demo.Msg.DatabaseInsertResponse) As %Status
{
    Set tSC = $$$OK
    Set pResponse = ##class(Demo.Msg.DatabaseInsertResponse).%New()
    
    Try {
        // Log del inicio
        $$$LOGINFO("Insertando registro en PostgreSQL via JDBC: "_pRequest.Name_", "_pRequest.Age_", "_pRequest.City)
        
        // Preparar el INSERT SQL
        Set sql = "INSERT INTO csv_records (name, age, city) VALUES (?, ?, ?)"
        
        // Ejecutar usando el Adapter
        Set tSC = ..Adapter.ExecuteUpdate(.nrows, sql, pRequest.Name, pRequest.Age, pRequest.City)
        
        If $$$ISERR(tSC) {
            Set pResponse.Success = 0
            Set pResponse.ErrorMessage = "Error al insertar en PostgreSQL: "_$System.Status.GetErrorText(tSC)
            $$$LOGERROR(pResponse.ErrorMessage)
        } Else {
            Set pResponse.Success = 1
            Set pResponse.RecordsAffected = nrows
            Set pResponse.Message = "Registro insertado exitosamente en PostgreSQL"
            $$$LOGINFO("✓ "_pResponse.Message_" (rows: "_nrows_")")
        }
        
    } Catch ex {
        Set tSC = ex.AsStatus()
        Set pResponse.Success = 0
        Set pResponse.ErrorMessage = "Exception en Postgres.JDBCOperation: "_ex.DisplayString()
        $$$LOGERROR(pResponse.ErrorMessage)
    }
    
    Quit tSC
}

XData MessageMap
{
<MapItems>
    <MapItem MessageType="Demo.Msg.DatabaseInsertRequest">
        <Method>Insert</Method>
    </MapItem>
</MapItems>
}

}
