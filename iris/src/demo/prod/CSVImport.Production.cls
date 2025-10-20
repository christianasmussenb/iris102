Class iris.src.demo.prod.CSVImport.Production Extends %RegisteredObject
{

XData ProductionDefinition
{
<Production Name="DEMO.prod.CSVImport.Production" LogGeneralTraceEvents="true">

  <!-- SERVICE: lee CSV con RecordMap -->
  <Item Name="BS.FileCSV" Category="Service" ClassName="EnsLib.RecordMap.Service.FileService" PoolSize="1" Enabled="true">
    <Setting Target="Adapter" Name="FilePath" Value="/data/IN"/>
    <Setting Target="Adapter" Name="FileSpec" Value="*.csv"/>
    <Setting Target="Adapter" Name="WorkPath" Value="/data/WIP"/>
    <Setting Target="Adapter" Name="ArchivePath" Value="/data/OUT"/>
    <Setting Target="Adapter" Name="FileAge" Value="3"/>
    <Setting Target="Adapter" Name="CallInterval" Value="5"/>
    <Setting Name="RecordMap" Value="DEMO.rm.SalesCSV"/>
    <Setting Name="TargetConfigNames" Value="BP.FileToMySQL"/>
  </Item>

  <!-- BP -->
  <Item Name="BP.FileToMySQL" Category="Process" ClassName="DEMO.bp.FileToMySQL" PoolSize="2" Enabled="true"/>

  <!-- BO -->
  <Item Name="BO.MySQL" Category="Operation" ClassName="DEMO.bo.MySQLInsert" PoolSize="2" Enabled="true"/>

</Production>
}
}
