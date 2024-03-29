USE [MorphisIM7U_TARM]
GO
/****** Object:  StoredProcedure [dbo].[X937_BankMichiganTransactions_TARM_GET]    Script Date: 1/10/2024 2:14:23 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[X937_BankMichiganTransactions_TARM_GET] (@LoadDateStart datetime, @LoadDateEnd datetime)
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @TodayDate date = GetDate(), @SSDateStart date, @SSDateEnd date

    IF @TodayDate < @LoadDateEnd
        SET @LoadDateEnd = @TodayDate

    --Traditional Deposits
    SELECT *
    FROM (
            SELECT CAST('1' + CAST(CheckedRecordID  AS varchar(20)) + '02' AS BIGINT) AS CheckedRecordID, SealNumber, LoadDate2, SUM(DeclaredAmount) AS DeclaredAmount, SUM(ActualAmount) AS ActualAmount, MICR, PackageType, [Location],
            CASE WHEN VaultID2 IN (102) THEN 'Detroit' ELSE 'Unknown' END AS SiteName, BagType
            FROM (  
            SELECT T1.OrderID  
                ,(CASE T1.CustomerID  
                WHEN 7911 THEN 1 --TCF BANK  
                WHEN 7893 THEN 2 --LEVEL ONE BANK  
                WHEN 7904 THEN 3 --OXFORD BANK  
                END) AS [BankID]  
                , T8.OrgName [BankName], T2.RecordID [UniqueID]
                , ISNULL(T7.BankAcctNumber, T18.AccountNumber) [MICR]
                , T2.LoadDate2, T2.VaultID2, T12.OrgName [Location]  
                , T10.OptionText [PackageType], T3.RecordID [CheckedRecordID], T3.SealNumber  
                , SUM(ISNULL(T4.CashValue,T14.CashValue)) [ActualAmount], T5.CashValue [DeclaredAmount]   
                , T17.OptionText AS BagType
		    FROM AcsCustomerOrders T1   
		    INNER JOIN AcsOrderSummary T2 ON T1.OrderID=T2.OrderID  
		    INNER JOIN AcsPackageChecked T3 ON T2.RecordID=T3.OsRecordID  
		    LEFT JOIN AcsPkgCheckedItems T4 ON T3.RecordID=T4.PRecordID AND T4.PCategory=0
		    INNER JOIN AcsPkgCheckedDecld T5 ON T3.RecordID=T5.PRecordID  
		    LEFT JOIN AtmOperation T6 ON T2.ATMID=T6.ATMID  
		    LEFT JOIN CmOrganizationEx T7 ON T6.LocationID=T7.OrgID  
		    LEFT JOIN CmOrganization T8 ON T1.CustomerID=T8.OrgID  
		    LEFT JOIN SwManagedItems T9 ON T4.ItemID=T9.ItemID  
		    LEFT JOIN SwOptionTexts T10 ON T3.PackageType=T10.OptionValue AND OptionGROUP='CPKGT' 
		    LEFT JOIN CmOrganization T12 ON T6.LocationID=T12.OrgID  
		    LEFT JOIN AcsPackageChecked2 T13 ON T3.RecordID=T13.PRecordID --Envelope info
		    LEFT JOIN AcsPkgCheckedItems T14 ON T13.RecordID=T14.PRecordID AND T14.PCategory=1
            LEFT JOIN AcsPackageCheckedEx T15 ON T3.RecordId = T15.RecordID
            LEFT JOIN AcsTcbServiceBags T16 ON T15.BagType=T16.BagType
            LEFT JOIN AcsTcbOptionTexts T17 ON T16.BagType=T17.RecordID AND T17.OptionGroup='BAGTP'
            LEFT JOIN VcmOrgAccounts T18 ON T15.RefAcctID=T18.RefAccountID
		    WHERE 1=1  
		    AND T2.OrderStatus<>2  
		    AND T3.PkgStatus=9 -- COPPS  (Processed/In-Vault) SELECT * FROM SwOptionTexts WHERE OptionGroup = 'copps'
		    AND T5.PCategory=0   
		    AND T5.DecldType=0  
            AND T2.LoadDate2 >= '2023-12-01' --Automation Start Date
            AND T2.LoadDate2 >= DATEADD(dd,-60,GetDate())
		    AND T2.LoadDate2 BETWEEN @LoadDateStart AND @LoadDateEnd  
		    AND T7.DepositX937 = 1  
		    AND T2.VaultID2 IN (102)  -- Bank Michigan 
            --AND ISNULL(T17.OptionText,'') != 'Smart Safe'
            GROUP BY T1.OrderID, T1.CustomerID, T8.OrgName, T12.OrgName, T2.RecordID, T3.RecordID, T3.SealNumber, T7.BankAcctNumber, T18.AccountNumber, T2.LoadDate2, T2.VaultID2, T10.OptionText, T5.CashValue, T17.OptionText  
         ) T1  
    GROUP BY CheckedRecordID, SealNumber, LoadDate2, MICR, PackageType, Location, VaultID2, BagType
    ) t
END
