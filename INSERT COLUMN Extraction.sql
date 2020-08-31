CREATE PROCEDURE getinsertscripttable            
       @pWorkingTag   varchar(  1),            
       @pTableNm      varchar(100)            
            
AS            
   declare @vcConvVar       varchar(20)  ,            
           @vcConvInt       varchar(20)  ,            
           @vcTableID       int          ,            
           @vcResults       varchar(8000),            
           @vcData          varchar(8000),            
           @vcDataTemp      varchar(8000),            
           @vcColNm         varchar(400) ,             
           @vcColType       varchar(400) ,            
           @vcColTypeLength varchar(400) ,             
           @nIsNullable     int          ,            
           @nCnt            int          ,            
           @nLoopCnt        int          ,          
           @pNotAddDate     char(01)     ,          
           @vcTemp          varchar(100)          
                       
          
   select @pNotAddDate = '0'            
          
   If @pTableNm = ''             
   BEGIN            
      select 'Parameter ERROR'            
      RETURN            
   END            
            
   select @vcTableID = id from sysobjects where name like @pTableNm            
               
   If @pTableNm like 'TC%' or @pTableNm like 'TD%' or @pTableNm like 'TL%'          
   BEGIN          
      If Exists (select 1 from syscolumns a with (nolock) join sysobjects b with (nolock)          
                                                            on a.Id = b.Id          
                                                           and b.name = @pTableNm          
                          where a.name = 'AddDate')          
         select @pNotAddDate = '1'          
   END          
          
   create table #TableLayOut (            
          Seq           int identity,            
          ColNm         varchar(400),            
          ColType       varchar(400),            
          ColTypeLength varchar(400),            
          isnullable    int          )            
            
   Insert Into #TableLayOut (ColNm, ColType, ColTypeLength, isnullable)            
          select a.name as ColNm     ,             
                 b.name as ColType   ,            
                 case when b.name = 'char'  or b.name = 'varchar'  then rtrim(b.name) + '(' + convert(varchar(30), a.length) + ')'            
                      when b.name = 'nchar' or b.name = 'nvarchar' then rtrim(b.name) + '(' + convert(varchar(30), round(a.length/2,0)) + ')'            
                      when b.name = 'decimal' or b.name = 'numeric' then rtrim(b.name) + '(' + convert(varchar(30), a.xprec) + ',' + convert(varchar(30), a.xscale) + ')'             
                      else b.name end as ColTypeLength,            
                 a.isnullable as isnullable            
                 from syscolumns a with (nolock) join systypes b with (nolock)             
                                                   on a.xtype = b.xusertype             
                 where a.id = @vcTableID            
            
   select @nCnt = count(*) from #TableLayOut            
            
   If @pWorkingTag = 'C'            
      GOTO CREATETABLE_PROC            
   Else            
      GOTO INSERTSCRIPT_PROC            
            
/************************************************************************************************************/            
CREATETABLE_PROC:            
            
   select @vcResults = 'CREATE TABLE ' + @pTableNm + ' ('            
            
   select @nLoopCnt = 1            
   declare CREATE_Cursor cursor for            
           select ColNm, ColTypeLength, Isnullable from #TableLayOut            
   open CREATE_Cursor            
     fetch next from CREATE_Cursor into @vcColNm, @vcColTypeLength, @nIsNullable            
   while (@@fetch_status = 0)            
   BEGIN            
      select @vcResults = @vcResults + char(13) + char(10) + char(9) + @vcColNm + char(9) + @vcColTypeLength + char(9)            
                          + case when @nIsNullable = 0 then 'NOT NULL'            
                                 when @nIsNullable = 1 then 'NULL   '            
                                 else 'Add IsNullable in StoredProcedure' end            
                          + case when @nLoopCnt = @nCnt then ') ' else ', ' end             
            
      select @nLoopCnt = @nLoopCnt + 1            
      fetch next from CREATE_Cursor into @vcColNm, @vcColTypeLength, @nIsNullable            
   END            
   close CREATE_Cursor            
   deallocate CREATE_Cursor            
            
   select @vcResults            
             
   create table #DATA ( String varchar(8000))            
   EXECUTE createindexinsert @pTableNm            
            
            
RETURN               
/************************************************************************************************************/            
INSERTSCRIPT_PROC:            
           
  select @vcData = ''      
      
   select @vcResults = 'select ' + '''' + 'Insert Into ' + @pTableNm + '('            
            
   select @nLoopCnt = 1            
   declare Rlt_Cursor cursor for            
           select ColNm, ColType from #TableLayOut order by Seq            
   open Rlt_Cursor            
   fetch next from Rlt_Cursor into @vcColNm, @vcColType            
   while (@@fetch_status = 0)            
   BEGIN            
      if @nLoopCnt = @nCnt            
      BEGIN            
         select @vcResults = @vcResults + @vcColNm + ") select '"            
            
         select @vcData = @vcData + char(13) +             
                                    case when @pNotAddDate = '1' and @vcColNm = 'AddDate'          
                                              then 'AddDate' -- " + '''' + convert(varchar(08), GetDate(), 112) + '''' "          
                                         when @vcColType = 'char' or @vcColType = 'varchar'            
                                              then " + '''' + IsNull(RTRIM(" + @vcColNm + "), '') + '''' "            
                                         when @vcColType = 'nchar' or @vcColType = 'nvarchar'            
                                              then " + 'N''' + IsNull(RTRIM(" + @vcColNm + "), '') + '''' "            
                                         when @vcColType = 'smallint' or @vcColType = 'tinyint' or @vcColType = 'int'             
                                              or @vcColType = 'numeric' or @vcColType = 'money' or @vcColType = 'float' or @vcColType = 'decimal'            
                                              then " + convert(varchar(30), IsNull(" + @vcColNm + ", 0)) "            
                                         when @vcColType = 'datetime' or @vcColType = 'smalldatetime'            
                                              then " + ''''  + convert(varchar(30), IsNull(" + @vcColNm + ", ''), 121) + '''' "            
                                         else 'Add DataType in StoredProcedure ' + @vcColNm end            
      END            
      else             
      BEGIN            
         select @vcResults = @vcResults + @vcColNm + ","              
            
         select @vcData = @vcData + char(13) +            
                                    case when @pNotAddDate = '1' and @vcColNm = 'AddDate'          
                                              then 'AddDate'          
                                         when @vcColType = 'char' or @vcColType = 'varchar'            
                                              then " + '''' + IsNull(RTRIM(" + @vcColNm + "), '') + ''',' "            
                                           when @vcColType = 'nchar' or @vcColType = 'nvarchar'            
                                              then " + 'N''' + IsNull(RTRIM(" + @vcColNm + "), '') + ''',' "            
                                         when @vcColType = 'smallint' or @vcColType = 'tinyint' or @vcColType = 'int'     
                                              or @vcColType = 'numeric' or @vcColType = 'money' or @vcColType = 'float' or @vcColType = 'decimal'            
                                              then " + convert(varchar(30), IsNull(" + @vcColNm + ", 0)) + ',' "       
                                         when @vcColType = 'datetime' or @vcColType = 'smalldatetime'            
                                              then " + '''' + convert(varchar(30), IsNull(" + @vcColNm + ", ''), 121) + ''',' "            
                                         WHEN @vcColType = 'bit'  
                                              THEN " + convert(varchar(30), IsNull(" + @vcColNm + ", 0)) + ',' "  
   else 'Add DataType in StoredProcedure ' + @vcColNm + '(' + @vcColType + ')' end            
      END            
            
      If len(@vcResults) + len(@vcData) > 7000            
      BEGIN            
         select @vcDataTemp = @vcData            
         select @vcData = ''            
      END            
            
      select @nLoopCnt = @nLoopCnt + 1            
      fetch next from Rlt_Cursor into @vcColNm, @vcColType            
   END            
   close Rlt_Cursor            
   deallocate Rlt_Cursor            
          
   Print @vcDataTemp   
   If IsNull(@vcDataTemp,'') > ''            
   BEGIN            
      select @vcResults = @vcResults + @vcDataTemp            
      select replace(@vcResults, ',AddDate', '')          
      select @vcData = @vcData + char(13) + char(10) + 'from ' + @pTableNm            
      select @vcData = replace(@vcData, "','"+char(13)+'AddDate', "''")          
      select @vcData          
   END            
   Else             
   BEGIN          
      select @vcResults = @vcResults + @vcData + char(13) + char(10) + 'from ' + @pTableNm            
      select @vcResults = replace(@vcResults, ',AddDate', '')          
      select @vcResults = replace(@vcResults, "','"+char(13)+'AddDate', "''")          
      select @vcResults          
   END            
            
            
RETURN            
/************************************************************************************************************/            
      
  
  
