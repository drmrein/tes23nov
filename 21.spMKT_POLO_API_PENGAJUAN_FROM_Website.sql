/*    ==Scripting Parameters==

    Source Server Version : SQL Server 2016 (13.0.1601)
    Source Database Engine Edition : Microsoft SQL Server Enterprise Edition
    Source Database Engine Type : Standalone SQL Server

    Target Server Version : SQL Server 2017
    Target Database Engine Edition : Microsoft SQL Server Standard Edition
    Target Database Engine Type : Standalone SQL Server
*/

USE [WISE_STAGING]
GO
/****** Object:  StoredProcedure [dbo].[spMKT_POLO_API_PENGAJUAN_FROM_Website]    Script Date: 11/16/21 10:46:07 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--===============================================================================================================================================================================
--||Author		: Arif 																																			 
--||Create date	: 22-11-2021																																					
--||Description	: <Stored procedure yang dipanggil dalam API Pengajuan dan Top Up From Website To Polo>																																	 
--||Version		: v1.0.20211122																																	 
--||History		:																																								
--||----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--|| Date           | Type    | Version        | Name                        | Description													|Detail                                            
--||----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--|| 22-11-2021     | Create  | v1.0.20211122   | Arif    		             | PR/2021/JAN/PMOB/003	                                        |Phase 1 - Project Kawan - API                                           
--===============================================================================================================================================================================
CREATE PROCEDURE [dbo].[spMKT_POLO_API_PENGAJUAN_FROM_Website] (@guid NVARCHAR(MAX), @parameterBody NVARCHAR(MAX))
AS
CREATE TABLE #RESPONSE_VAL (
	responseMessage VARCHAR(max)
	,responseCode VARCHAR(3)
	)

CREATE TABLE #RESPONSE_EXEC_KAWAN (
	trLogApiXID VARCHAR(100)
	,pengajuan VARCHAR(100)
	,taskIdPolo VARCHAR(100)
	,statusPengajuan VARCHAR(100)
	,statusProspek VARCHAR(100)
	,mtType VARCHAR(100)
	,isSuccess VARCHAR(100)
	,errorMsg VARCHAR(MAX)
	)

DECLARE @resultVal CHAR(1) = 'T'
	,@nextFlag INT = 1 --1 lanjut, 0 stop
DECLARE @labelId BIGINT = '20'
DECLARE @return CHAR(1) = 'T'
	,@stringValue NVARCHAR(max)
	,@question_api VARCHAR(max)

DECLARE @trLogApiXID VARCHAR(100)
	,@pengajuan VARCHAR(100)
	,@taskIdPolo VARCHAR(100)
	,@statusPengajuan VARCHAR(100)
	,@statusProspek VARCHAR(100)
	,@mtType VARCHAR(100)
	,@message_resposnse VARCHAR(100) = 'Success'

DECLARE @errorSystemCode VARCHAR(100)

DECLARE @param_in_err VARCHAR(MAX)
		,@lengh_char VARCHAR(10)

DECLARE @kelurahanLeg VARCHAR (50)
		,@kecamatanLeg VARCHAR(50)
		,@kabupatenLeg VARCHAR(50)
		,@itemMerk VARCHAR(50)
		,@assetType VARCHAR(50)
		,@assetCode VARCHAR(50)
		,@insuranceType VARCHAR(50)

-- Default Values
DECLARE @SOURCE_DATA VARCHAR(100) = 'Website'
,@JENIS_TASK VARCHAR(100) = 'Penawaran'
,@KILAT_PINTAR VARCHAR(1) = 'F'
,@USR_CRT VARCHAR(100) = 'API Pengajuan From Website To Polo'
,@ELIGIBLE_FLAG VARCHAR(1) = 'T'
,@ELIGIBLE_FLAG_DT DATETIME = GETDATE()
,@TASK_ID VARCHAR(100) = 'POL' + WISE_STAGING.DBO.LPAD(NEXT VALUE FOR WISE_STAGING.DBO.MKT_POLO_TASK_ID_SEQ, 9, 0)
,@CYCLING VARCHAR(100) = '0'
,@DISTRIBUTED_DT DATETIME = GETDATE()


DECLARE @processFlag INT = 0 /*1=ERROR, 0=NEXTSTEP*/
DECLARE @apiName VARCHAR(200)
,@responseID VARCHAR(500)
,@messageCodeX NVARCHAR(MAX)
,@responseCode NVARCHAR(MAX)
,@messageX NVARCHAR(MAX)
,@messageErr NVARCHAR(MAX)
,@responseMessage NVARCHAR(MAX)
,@taskId VARCHAR(100)
,@response_id BIGINT

/*Declare Response Code*/
DECLARE @successCode VARCHAR(3)
	,@errorParamCode VARCHAR(3)
	,@errorSubZipCode VARCHAR(3)
	,@errorGeneral VARCHAR(3)


-- SELECT @errorSubZipCode = PARAMETER_VALUE
-- FROM M_MKT_POLO_PARAMETER
-- WHERE PARAMETER_ID = 'WEBSITE_ERROR_SUB_ZIP_CODE'

SELECT @successCode = PARAMETER_VALUE
FROM M_MKT_POLO_PARAMETER
WHERE PARAMETER_ID = 'POLO_RESPCODE_SUCCESS'

SELECT @errorParamCode = PARAMETER_VALUE
FROM M_MKT_POLO_PARAMETER
WHERE PARAMETER_ID = 'POLO_RESPCODE_UPDDATA_ERRPARAM'

SELECT @errorSystemCode = PARAMETER_VALUE
FROM M_MKT_POLO_PARAMETER
WHERE PARAMETER_ID = 'POLO_RESPCODE_UPDDATA_ERRSYS'

/*Param tidak boleh null*/
IF @parameterBody IS NULL
BEGIN
	SET @processFlag = 1
END

IF @processFlag = 0
BEGIN
	BEGIN TRY
		/*CREATE LOg REQUEST*/
		SELECT *
		INTO #PARAM
		FROM fnMKT_POLO_parseJSON(@parameterBody)

		SELECT @apiName = stringvalue
		FROM #PARAM
		WHERE UPPER([NAME]) = 'IDNAME'


		SELECT @pengajuan = stringvalue
		FROM #PARAM
		WHERE UPPER([NAME]) = 'SUBMISSIONNO'

		SELECT @kelurahanLeg = stringvalue
		FROM #PARAM
		WHERE UPPER([NAME]) = 'LEGALVILLAGE'
		SELECT @kecamatanLeg = stringvalue
		FROM #PARAM
		WHERE UPPER([NAME]) = 'LEGALSUBDISTRICT'
		SELECT @kabupatenLeg = stringvalue
		FROM #PARAM
		WHERE UPPER([NAME]) = 'LEGALDISTRICT'
		SELECT @itemMerk = stringvalue
		FROM #PARAM
		WHERE UPPER([NAME]) = 'ITEMMERK'
		SELECT @assetType = stringvalue
		FROM #PARAM
		WHERE UPPER([NAME]) = 'ASSETTYPE'
		SELECT @assetCode = stringvalue
		FROM #PARAM
		WHERE UPPER([NAME]) = 'ASSETCODE'
		SELECT @insuranceType = stringvalue
		FROM #PARAM
		WHERE UPPER([NAME]) = 'INSURANCETYPE'

		-- SELECT @kelurahanLeg

		SELECT
			B.QUESTION_API AS [NAME]
			,case when a.StringValue = 'null' then null else a.StringValue end as StringValue
			,ROW_NUMBER() OVER (
				ORDER BY element_id
				) AS rowNum,
				e.*,
			D.IS_MANDATORY
		INTO #PARAM_FINAL
		FROM #PARAM A
		JOIN M_MKT_POLO_QUESTIONGROUP_D B ON A.NAME = B.QUESTION_API
		JOIN M_MKT_POLO_QUESTIONGROUP_H C ON B.M_MKT_POLO_QUESTIONGROUP_H_ID = C.M_MKT_POLO_QUESTIONGROUP_H_ID
			AND C.QUESTIONGROUP_NAME = @apiName --'Data_Pengajuan_Website_To_Polo'  
		JOIN M_MKT_POLO_QUESTION_LIST D ON B.QUESTION_IDENTIFIER = D.QUESTION_IDENTIFIER
		JOIN M_MKT_POLO_QUESTION_LABEL E ON D.M_MKT_POLO_QUESTION_LABEL_ID = E.M_MKT_POLO_QUESTION_LABEL_ID
		WHERE ValueType != 'object'

		SELECT @responseID = newid()

		INSERT INTO T_MKT_POLO_APILOGREQUEST (
			ID_NAME
			,PARAMETER
			,REQUEST_DT
			,RESPONSE_ID
			,DTM_CRT
			,USR_CRT
			)
		VALUES (
			@apiName
			,@parameterBody
			,GETDATE()
			,@responseID
			,GETDATE()
			,'System'
			)


		/*validasi parameter*/
		INSERT INTO #RESPONSE_VAL
		EXEC [dbo].[spMKT_POLO_VALIDATIONLABEL] @parameterBody
			,NULL
			,NULL

		SELECT @messageCodeX = responseCode
			,@messageX = responseMessage
		FROM #RESPONSE_VAL

		IF @messageCodeX != '200'
		BEGIN
			/*Jika parameter tidak sesuai, proses akan di stop*/
			SET @processFlag = 1
			SET @messageErr = @messageX
		END


		/*proses validasi*/
		IF @processFlag = 0
		BEGIN
		
			/*validasi Mandatory*/
			IF @return != 'F'
			BEGIN
				DECLARE C1 CURSOR
				FOR
				SELECT M_MKT_POLO_QUESTION_LABEL_ID
					,StringValue
					,[NAME]
				FROM #PARAM_FINAL
				--WHERE RESPONSE_MANDATORY IS NOT NULL
				WHERE IS_MANDATORY = 1

				OPEN C1

				FETCH NEXT
				FROM C1
				INTO @labelId
					,@stringValue
					,@question_api

				WHILE @@FETCH_STATUS = 0
				BEGIN
					BEGIN
						EXEC [dbo].[spMKT_POLO_ValidationParamInMandatory] @labelId = @labelId
							,@value = @stringValue
							,@result = @return OUTPUT
							,@responseCode = @responseCode OUTPUT

						--SELECT	@return as 'returnManda', @responseCode as 'responseCode'
						IF @return = 'F'
						BEGIN
							SET @nextFlag = 0
							SET @param_in_err = @question_api

							BREAK
						END
					END

					FETCH NEXT
					FROM C1
					INTO @labelId
						,@stringValue
						,@question_api
				END

				CLOSE C1

				DEALLOCATE C1
			END

			/*validasi Length*/
			IF @return != 'F'
			BEGIN
				DECLARE C1 CURSOR
				FOR
				SELECT M_MKT_POLO_QUESTION_LABEL_ID
					,StringValue
					,[NAME]
				FROM #PARAM_FINAL
				WHERE RESPONSE_LENGTH IS NOT NULL

				OPEN C1

				FETCH NEXT
				FROM C1
				INTO @labelId
					,@stringValue
					,@question_api

				WHILE @@FETCH_STATUS = 0
				BEGIN
					BEGIN
						EXEC [dbo].[spMKT_POLO_ValidationParamInLength] @labelId = @labelId
							,@value = @stringValue
							,@result = @return OUTPUT
							,@responseCode = @responseCode OUTPUT

						--SELECT	@return as 'return' , @responseCode as 'responseCode'
						IF @return = 'F'
						BEGIN
							SET @nextFlag = 0
							SET @param_in_err = @question_api
							SELECT @lengh_char = MPLBL.MAX_LENGTH FROM WISE_STAGING.dbo.M_MKT_POLO_QUESTION_LABEL  MPLBL
							JOIN WISE_STAGING.dbo.M_MKT_POLO_QUESTION_LIST MPLIST ON MPLIST.M_MKT_POLO_QUESTION_LABEL_ID = MPLBL.M_MKT_POLO_QUESTION_LABEL_ID
							JOIN WISE_STAGING.dbo.M_MKT_POLO_QUESTIONGROUP_D MPGD ON MPGD.QUESTION_IDENTIFIER = MPLIST.QUESTION_IDENTIFIER
							WHERE MPGD.QUESTION_API = @question_api
							
							BREAK
						END
					END

					FETCH NEXT
					FROM C1
					INTO @labelId
						,@stringValue
						,@question_api
				END

				CLOSE C1

				DEALLOCATE C1
			END
			
		
			/*validasi Numeric*/
			IF @return != 'F'
			BEGIN
				DECLARE C1 CURSOR
				FOR
				SELECT M_MKT_POLO_QUESTION_LABEL_ID
					,StringValue
					,[NAME]
				FROM #PARAM_FINAL
				WHERE RESPONSE_NUMERIC IS NOT NULL

				OPEN C1

				FETCH NEXT
				FROM C1
				INTO @labelId
					,@stringValue
					,@question_api

				WHILE @@FETCH_STATUS = 0
				BEGIN
					BEGIN
						EXEC [dbo].[spMKT_POLO_ValidationParamInNumeric] @labelId = @labelId
							,@value = @stringValue
							,@result = @return OUTPUT
							,@responseCode = @responseCode OUTPUT

						--SELECT @responseCode AS 'TESETTT'

						--SELECT	@return as 'returnNumeric', @responseCode as 'responseCode'
						IF @return = 'F'
						BEGIN
							SET @nextFlag = 0
							SET @param_in_err = @question_api

							BREAK
						END
					END

					FETCH NEXT
					FROM C1
					INTO @labelId
						,@stringValue
						,@question_api
				END

				CLOSE C1

				DEALLOCATE C1
			END

			/*validasi Email*/
			IF @return != 'F'
			BEGIN
				DECLARE C1 CURSOR
				FOR
				SELECT M_MKT_POLO_QUESTION_LABEL_ID
					,StringValue
					,[NAME]
				FROM #PARAM_FINAL
				WHERE RESPONSE_EMAIL IS NOT NULL

				OPEN C1

				FETCH NEXT
				FROM C1
				INTO @labelId
					,@stringValue
					,@question_api

				WHILE @@FETCH_STATUS = 0
				BEGIN
					BEGIN
						EXEC [dbo].[spMKT_POLO_ValidationParamInEmail] @labelId = @labelId
							,@value = @stringValue
							,@result = @return OUTPUT
							,@responseCode = @responseCode OUTPUT

						--SELECT	@return as 'returnManda', @responseCode as 'responseCode'
						IF @return = 'F'
						BEGIN
							SET @nextFlag = 0
							SET @param_in_err = @question_api

							BREAK
						END
					END

					FETCH NEXT
					FROM C1
					INTO @labelId
						,@stringValue
						,@question_api
				END

				CLOSE C1

				DEALLOCATE C1
			END

			IF @nextFlag = 1
			BEGIN
				IF @processFlag = 0
				BEGIN
								
					BEGIN
						BEGIN
							DECLARE @isSuccess VARCHAR(50) = '200'
							DECLARE @SELECT VARCHAR(MAX)
									,@SELECTLIST VARCHAR(MAX)
									,@listFinal VARCHAR(MAX)
									,@SQLSTR NVARCHAR(MAX)

							DECLARE @ID_NAME VARCHAR(100)
								,@PROSPECT_STAT_OLD VARCHAR(50)
								,@PROSPECT_STAT VARCHAR(50)
								,@EMP_POSITION VARCHAR(100)
								,@ORDER_IN_ID BIGINT
								,@FIELD_PERSON VARCHAR(100)			
							

							DECLARE @T_MKT_POLO_ORDER_IN_ID BIGINT
							SET @T_MKT_POLO_ORDER_IN_ID = 1
									
							/*mendapatkan nilai dalam bentuk row*/
							SELECT QUESTION_CODE
								,rowNum
							INTO #tempList
							FROM #PARAM_FINAL

							SELECT @selectList = ''

							SELECT @selectList = @selectList + QUESTION_CODE + ', '
							FROM #tempList

							SELECT @listFinal = substring(@selectList, 0, convert(INT, len(@selectList) - 0))

							SET @sqlStr = ' SELECT ' + @listFinal + ' INTO ##listRow20210820 FROM (SELECT STRINGVALUE, QUESTION_CODE FROM #PARAM_FINAL) D
							PIVOT (MAX(STRINGVALUE) FOR QUESTION_CODE IN  (' + @listFinal + ')) x '

							EXEC SP_EXECUTESQL @sqlStr

							
						END
						-- SELECT * FROM ##listRow20210820
						SELECT @ID_NAME = id_name
							,@pengajuan = PENGAJUAN_NO
							FROM ##listRow20210820

						-- validasi kota, dll
						-- BEGIN
						
						DECLARE @checkLegalSubZipCode VARCHAR(20) = ''

						SELECT TOP 1 @checkLegalSubZipCode =  RZ.SUB_ZIPCODE
						FROM CONFINS.DBO.REF_ZIPCODE RZ WITH (NOLOCK)
						INNER JOIN CONFINS.DBO.REF_PROV_DISTRICT RPD WITH (NOLOCK) ON RPD.REF_PROV_DISTRICT_ID = RZ.REF_PROV_DISTRICT_ID
						INNER JOIN (SELECT PRV.NAME as PROV_NAME, kota.REF_PROV_DISTRICT_ID AS KOTA_ID, kota.NAME as KOTA_NAME
							FROM CONFINS.DBO.REF_PROV_DISTRICT PRV WITH (NOLOCK)
							INNER JOIN CONFINS.DBO.REF_PROV_DISTRICT KOTA WITH (NOLOCK)
							ON PRV.REF_PROV_DISTRICT_ID = KOTA.PARENT_ID
							WHERE PRV.TYPE = 'PRV'
							AND KOTA.TYPE = 'DIS'
							AND KOTA.IS_ACTIVE = '1'
							AND PRV.IS_ACTIVE = '1'
							) N ON N.KOTA_ID = RZ.REF_PROV_DISTRICT_ID
						WHERE RZ.KELURAHAN = @kelurahanLeg AND RZ.KECAMATAN = @kecamatanLeg AND RZ.CITY = @kabupatenLeg AND RZ.IS_ACTIVE = '1' AND RPD.IS_ACTIVE = '1'
						
								
						-- validasi kota, kabupaten, dll
						-- 1. kabupatenLeg
						
						IF @kabupatenLeg <> '' AND @kabupatenLeg <> 'null' AND NOT EXISTS (SELECT RZ.CITY FROM CONFINS.DBO.REF_ZIPCODE RZ WITH (NOLOCK)
						JOIN CONFINS.DBO.REF_PROV_DISTRICT B WITH (NOLOCK) ON B.REF_PROV_DISTRICT_ID = RZ.REF_PROV_DISTRICT_ID
						WHERE RZ.IS_ACTIVE = '1' AND RZ.CITY NOT IN ('KOTA','KABUPATEN') AND RZ.CITY = @kabupatenLeg)
						BEGIN
							SET @processFlag = 1
							SELECT @errorParamCode = PARAMETER_VALUE
							FROM M_MKT_POLO_PARAMETER
							WHERE PARAMETER_ID = 'API_ERROR_LEGAL_DISTRICT' AND IS_ACTIVE=1
							-- SELECT 'kabupatenLeg'	
						END

						-- -- 2. kecamatanLeg
						ELSE IF @kecamatanLeg <> '' AND @kecamatanLeg <> 'null' AND NOT EXISTS (SELECT RZ.KECAMATAN FROM CONFINS.DBO.REF_ZIPCODE RZ WITH (NOLOCK)
						JOIN CONFINS.DBO.REF_PROV_DISTRICT B WITH (NOLOCK) ON B.REF_PROV_DISTRICT_ID = RZ.REF_PROV_DISTRICT_ID
						WHERE RZ.IS_ACTIVE = '1' AND RZ.CITY NOT IN ('KOTA','KABUPATEN') AND RZ.KECAMATAN = @kecamatanLeg)
						BEGIN

							SET @processFlag = 1

							SELECT @errorParamCode = PARAMETER_VALUE
							FROM M_MKT_POLO_PARAMETER
							WHERE PARAMETER_ID = 'API_ERROR_LEGAL_SUB_DISTRICT' AND IS_ACTIVE=1
							-- SELECT 'kecamatanLeg'	
						END

						-- -- 3. kelurahanLeg
						ELSE IF @kelurahanLeg <> '' AND @kelurahanLeg <> 'null' AND NOT EXISTS (SELECT RZ.KELURAHAN FROM CONFINS.DBO.REF_ZIPCODE RZ WITH (NOLOCK)
						JOIN CONFINS.DBO.REF_PROV_DISTRICT B WITH (NOLOCK) ON B.REF_PROV_DISTRICT_ID = RZ.REF_PROV_DISTRICT_ID
						WHERE RZ.IS_ACTIVE = '1' AND RZ.CITY NOT IN ('KOTA','KABUPATEN') AND RZ.KELURAHAN = @kelurahanLeg)
						BEGIN
							SET @processFlag = 1

							SELECT @errorParamCode = PARAMETER_VALUE
							FROM M_MKT_POLO_PARAMETER
							WHERE PARAMETER_ID = 'API_ERROR_LEGAL_VILLAGE' AND IS_ACTIVE=1
							-- SELECT 'kelurahanLeg'	
						END

						-- -- 4. merkKendaraan
						ELSE IF @itemMerk <> '' AND @itemMerk <> 'null' AND NOT EXISTS (SELECT ASSET_HIERARCHY_L1_NAME FROM CONFINS..ASSET_HIERARCHY_L1 WITH (NOLOCK) WHERE IS_ACTIVE = 1 AND ASSET_HIERARCHY_L1_NAME = @itemMerk )
						BEGIN
							SET @processFlag = 1

							SELECT @errorParamCode = PARAMETER_VALUE
							FROM M_MKT_POLO_PARAMETER
							WHERE PARAMETER_ID = 'API_ERROR_ITEM_MERK' AND IS_ACTIVE=1

							
						END

						-- -- 5. typeKendaraan
						ELSE IF @assetType <> '' AND @assetType <> 'null' AND NOT EXISTS (SELECT ASSET_TYPE_CODE FROM CONFINS..ASSET_TYPE WITH (NOLOCK) WHERE ASSET_TYPE_CODE = @assetType)
						BEGIN
							SET @processFlag = 1

							SELECT @errorParamCode = PARAMETER_VALUE
							FROM M_MKT_POLO_PARAMETER
							WHERE PARAMETER_ID = 'API_ERROR_ASSET_TYPE' AND IS_ACTIVE=1
							-- SELECT 'typeKendaraan'	
						END

						-- -- 6. Asset Code Kendaraan
						ELSE IF @assetCode <> '' AND @assetCode <> 'null' AND NOT EXISTS (SELECT ASSET_CODE FROM CONFINS..ASSET_MASTER WITH (NOLOCK) WHERE IS_ACTIVE = 1 AND ASSET_CODE = @assetCode)
						BEGIN
							SET @processFlag = 1

							SELECT @errorParamCode = PARAMETER_VALUE
							FROM M_MKT_POLO_PARAMETER
							WHERE PARAMETER_ID = 'API_ERROR_ASSET_CODE' AND IS_ACTIVE=1
							-- SELECT 'typeKendaraan'	
						END

						-- -- 7. insuranceType
						ELSE IF @insuranceType <> '' AND @insuranceType <> 'null' AND NOT EXISTS (SELECT MAIN_CVG_TYPE_CODE FROM CONFINS..REF_MAIN_CVG_TYPE WITH (NOLOCK) WHERE IS_ACTIVE = 1 AND MAIN_CVG_TYPE_CODE = @insuranceType)
						BEGIN
							SET @processFlag = 1

							SELECT @errorParamCode = PARAMETER_VALUE
							FROM M_MKT_POLO_PARAMETER
							WHERE PARAMETER_ID = 'API_ERROR_INSURANCE_TYPE' AND IS_ACTIVE=1
							-- SELECT 'insuranceType'	
						END

						-- 8. legalSubZipCode @checkLegalSubZipCode = 
						
						-- ELSE IF NOT EXISTS (SELECT TOP 1  RZ.SUB_ZIPCODE
						-- FROM CONFINS.DBO.REF_ZIPCODE RZ WITH (NOLOCK)
						-- INNER JOIN CONFINS.DBO.REF_PROV_DISTRICT RPD WITH (NOLOCK) ON RPD.REF_PROV_DISTRICT_ID = RZ.REF_PROV_DISTRICT_ID
						-- INNER JOIN (SELECT PRV.NAME as PROV_NAME, kota.REF_PROV_DISTRICT_ID AS KOTA_ID, kota.NAME as KOTA_NAME
						-- 	FROM CONFINS.DBO.REF_PROV_DISTRICT PRV WITH (NOLOCK)
						-- 	INNER JOIN CONFINS.DBO.REF_PROV_DISTRICT KOTA WITH (NOLOCK)
						-- 	ON PRV.REF_PROV_DISTRICT_ID = KOTA.PARENT_ID
						-- 	WHERE PRV.TYPE = 'PRV'
						-- 	AND KOTA.TYPE = 'DIS'
						-- 	AND KOTA.IS_ACTIVE = '1'
						-- 	AND PRV.IS_ACTIVE = '1'
						-- 	) N ON N.KOTA_ID = RZ.REF_PROV_DISTRICT_ID
						-- WHERE RZ.KELURAHAN = @kelurahanLeg AND RZ.KECAMATAN = @kecamatanLeg AND RZ.CITY = @kabupatenLeg AND RZ.IS_ACTIVE = '1' AND RPD.IS_ACTIVE = '1') 
						-- ELSE IF NOT EXISTS (@checkLegalSubZipCode)

						/* keperluan subzipcode
						ELSE IF (@checkLegalSubZipCode = '' AND @kelurahanLeg <> '' AND @kelurahanLeg <> 'null' AND @kecamatanLeg <> '' AND @kecamatanLeg <> 'null' AND @kabupatenLeg <> '' AND @kabupatenLeg <> 'null')
						BEGIN 
							SET @processFlag = 1

							SELECT @errorParamCode = PARAMETER_VALUE
							FROM M_MKT_POLO_PARAMETER
							WHERE PARAMETER_ID = 'API_ERROR_SUB_ZIP_CODE' AND IS_ACTIVE=1

							-- SELECT 'SUB ZIP CODE IS NOT VALID'	

						END
						*/
						-- END
						-- end validasi kota

						-- ###SUKSES ORDER IN
						IF @processFlag = 0
						BEGIN
							DECLARE @LAST_T_MKT_POLO_ORDER_IN_ID BIGINT
							DECLARE @NEW_TASK_ID VARCHAR(100)
							-- T_MKT_POLO_ORDER_IN
							INSERT INTO WISE_STAGING.dbo.T_MKT_POLO_ORDER_IN (
								ID_NO, 
								CUST_NAME, 
								ADDR_LEG, 
								KABUPATEN_LEG, 
								KECAMATAN_LEG, 
								KELURAHAN_LEG, 
								RT_LEG, 
								RW_LEG, 
								PHONE1,
								ASSET_TYPE,
								ITEM_TYPE,
								ITEM_YEAR, 
								TENOR, 
								DOWN_PAYMENT, 
								TASK_ID, 
								SUB_ZIPCODE_LEG,
								DTM_CRT, 
								SOURCE_DATA, 
								KILAT_PINTAR, 
								USR_CRT, 
								ELIGIBLE_FLAG, 
								ELIGIBLE_FLAG_DT, 
								CYCLING, 
								DISTRIBUTED_DT,
								JENIS_TASK,
								PLAFOND)
							
							SELECT 
								ID_NO, 
								CUST_NAME, 
								ADDR_LEG, 
								KABUPATEN_LEG, 
								KECAMATAN_LEG, 
								KELURAHAN_LEG, 
								RT_LEG, 
								RW_LEG, 
								PHONE1,
								ASSET_TYPE,
								ITEM_TYPE,
								ITEM_YEAR, 
								TENOR, 
								DOWN_PAYMENT, 
								-- 'POL' + WISE_STAGING.DBO.LPAD(NEXT VALUE FOR WISE_STAGING.DBO.MKT_POLO_TASK_ID_SEQ, 9, 0),
								@TASK_ID,
								@checkLegalSubZipCode,
								GETDATE(), 
								@SOURCE_DATA, 
								@KILAT_PINTAR, 
								@USR_CRT, 
								@ELIGIBLE_FLAG, 
								@ELIGIBLE_FLAG_DT, 
								@CYCLING,
								@DISTRIBUTED_DT,
								@JENIS_TASK,
								EST_MAX_PLAFOND_AMT
							FROM ##listRow20210820

							-- T_MKT_POLO_ORDER_IN_X
							SELECT @LAST_T_MKT_POLO_ORDER_IN_ID = CAST(scope_identity() AS int);
							SELECT @NEW_TASK_ID = TASK_ID FROM WISE_STAGING.dbo.T_MKT_POLO_ORDER_IN WHERE T_MKT_POLO_ORDER_IN_ID = @LAST_T_MKT_POLO_ORDER_IN_ID
							SET @taskIdPolo = @NEW_TASK_ID
							INSERT INTO WISE_STAGING.dbo.T_MKT_POLO_ORDER_IN_X (
								T_MKT_POLO_ORDER_IN_ID,
								PENGAJUAN_NO, 
								LOB, 
								MERK_KENDARAAN, 
								INSURANCE_TYPE, 
								--EST_MAX_PLAFOND_AMT, 
								DTM_CRT, 
								USR_CRT,
								EMAIL)
							SELECT @LAST_T_MKT_POLO_ORDER_IN_ID,
								PENGAJUAN_NO,
								LOB,
								MERK_KENDARAAN,
								INSURANCE_TYPE,
								--EST_MAX_PLAFOND_AMT,
								GETDATE(), 
								@USR_CRT, 
								EMAIL		
							FROM ##listRow20210820
						END
						ELSE
						BEGIN
							SET @processFlag = 1
						END

						INSERT INTO #RESPONSE_EXEC_KAWAN (
									trLogApiXID
									,pengajuan
									,taskIdPolo
									,mtType
									,isSuccess
									,errorMsg
									)
								SELECT NULL AS trLogApiXID
									,@pengajuan AS submissionNo
									,@taskIdPolo AS taskIdPolo
									,'Api Feedback POLO' AS mtType
									,@isSuccess AS isSuccess
									,@message_resposnse AS errorMsg

						DROP TABLE ##listRow20210820
					END
				
				END
			END
			ELSE
			BEGIN
				-- SELECT 'Terdapat reject, Code : ' + cast(@responseCode AS VARCHAR(10))
				set @processFlag = 1
			END
		END
				
		
		IF @processFlag = 0
		BEGIN
			/*insert log response - valid*/
			SELECT @responseCode = RESPONSE_CODE
				,@responseMessage = RESPONSE_MESSAGE
			FROM M_MKT_POLO_RESPONSECODE
			WHERE RESPONSE_CODE = @successCode

			INSERT INTO T_MKT_POLO_APILOGRESPONSE (
				ID_NAME
				,TASK_ID
				,RESPONSE_CODE
				,RESPONSE_MESSAGE
				,ERROR_DESC
				,RESPONSE_DT
				,RESPONSE_ID
				,DTM_CRT
				,USR_CRT
				)
			VALUES (
				@apiName
				,@taskIdPolo
				,@responseCode
				,@responseMessage
				,NULL
				,GETDATE()
				,@responseID
				,GETDATE()
				,'System'				
				)

			SELECT @response_id = T_MKT_POLO_APILOGRESPONSE_ID
			FROM T_MKT_POLO_APILOGRESPONSE
			WHERE RESPONSE_ID = @responseID

			UPDATE WISE_STAGING.dbo.T_MKT_POLO_APILOGRESPONSE SET PARAMETER=(
				SELECT @response_id trLogApiXID
					,pengajuan submissionNo
					,taskIdPolo					
					,mtType
					,@responseCode responseCode
					,errorMsg responseMessage
				FROM #RESPONSE_EXEC_KAWAN FOR JSON path, WITHOUT_ARRAY_WRAPPER) 
				WHERE RESPONSE_ID = @responseID

			-- select @apiName
			SELECT @response_id trLogApiXID
					,pengajuan submissionNo
					,taskIdPolo
					,mtType
					,@responseCode responseCode
					,errorMsg responseMessage
				FROM #RESPONSE_EXEC_KAWAN
		END
		ELSE
		BEGIN			
			if @responseCode <> ''
				BEGIN
					if @responseCode <> @errorParamCode
					begin
						/*insert log response - invalid*/
						SELECT @responseCode = RESPONSE_CODE
							,@responseMessage = RESPONSE_MESSAGE
						FROM M_MKT_POLO_RESPONSECODE
						WHERE RESPONSE_CODE = @responseCode
					end
					else
					begin
						
						/*insert log response - invalid*/
						SELECT @responseCode = RESPONSE_CODE
							,@responseMessage = RESPONSE_MESSAGE
						FROM M_MKT_POLO_RESPONSECODE
						WHERE RESPONSE_CODE = @errorParamCode
					end
				END
			ELSE
			begin
				/*insert log response - invalid*/
				SELECT @responseCode = RESPONSE_CODE
					,@responseMessage = RESPONSE_MESSAGE
				FROM M_MKT_POLO_RESPONSECODE
				WHERE RESPONSE_CODE = @errorParamCode
			end
			if @responseCode = '01'
			BEGIN
				SET @responseMessage = @responseMessage +' - '+ @messageErr
			END 
			
			INSERT INTO T_MKT_POLO_APILOGRESPONSE (
				ID_NAME				
				,RESPONSE_CODE
				,RESPONSE_MESSAGE				
				,RESPONSE_DT
				,RESPONSE_ID
				,DTM_CRT
				,USR_CRT
				)
			VALUES (
				@apiName				
				,@responseCode				
				,@responseMessage
				,GETDATE()
				,@responseID
				,GETDATE()
				,'System'				
		
				)
			-- SELECT 'Terdapat reject, Code : ' + cast(@responseCode AS VARCHAR(10))
			SELECT @response_id = T_MKT_POLO_APILOGRESPONSE_ID
					FROM T_MKT_POLO_APILOGRESPONSE
					WHERE RESPONSE_ID = @responseID
				
			IF @responseCode IN ('10','20','30')
			BEGIN
				
				SET @responseMessage = REPLACE(@responseMessage, '[Param_IN]', @param_in_err)
				IF (SELECT CHARINDEX('[n]', @responseMessage)) <> 0
				BEGIN 
					SET @responseMessage = REPLACE(@responseMessage, '[n]', @lengh_char)
				END
			END

			UPDATE WISE_STAGING.dbo.T_MKT_POLO_APILOGRESPONSE SET RESPONSE_MESSAGE=@responseMessage, PARAMETER=(
			SELECT @response_id trLogApiXID
					,CASE WHEN @pengajuan <> '' THEN @pengajuan ELSE 'null' END submissionNo --@pengajuan submissionNo
					,CASE WHEN @taskIdPolo <> '' THEN @taskIdPolo ELSE 'null' END taskIdPolo
					,'Api Feedback POLO' mtType
					,@responseCode responseCode
					,@responseMessage responseMessage FOR JSON path, WITHOUT_ARRAY_WRAPPER)
				WHERE RESPONSE_ID = @responseID

			SELECT @response_id trLogApiXID
							,@pengajuan submissionNo
							,'' taskIdPolo
							,'Api Feedback POLO' mtType
							,@responseCode responseCode
							,@responseMessage responseMessage
		END
	END TRY
	
	BEGIN CATCH
		DECLARE @ERRMSG VARCHAR(MAX)
			,@ERRSEVERITY INT
			,@ERRSTATE INT
			,@ERR_LINE VARCHAR(MAX)
			,@messageSystemErr VARCHAR(max)

		SELECT @responseCode = RESPONSE_CODE
			,@responseMessage = RESPONSE_MESSAGE
		FROM M_MKT_POLO_RESPONSECODE
		WHERE RESPONSE_CODE = @errorSystemCode

		SELECT @ERRMSG = ERROR_MESSAGE()
			,@ERRSEVERITY = ERROR_SEVERITY()
			,@ERRSTATE = ERROR_STATE()
			,@ERR_LINE = ERROR_LINE()

		SET @messageSystemErr = 'Error : ' + ISNULL(@messageX, '') + ISNULL(@ERRMSG, '') + ' at Line : ' + ISNULL(CAST(@ERR_LINE AS VARCHAR), '')

		/*insert log response - Error*/
		INSERT INTO T_MKT_POLO_APILOGRESPONSE (
			ID_NAME
			,TASK_ID
			,RESPONSE_CODE
			,RESPONSE_MESSAGE
			,ERROR_DESC
			,RESPONSE_DT
			,RESPONSE_ID
			,DTM_CRT
			,USR_CRT
			,PARAMETER
			)
		VALUES (
			@apiName
			,@taskIdPolo
			,@responseCode
			,@responseMessage
			,@messageSystemErr
			,GETDATE()
			,@responseID
			,GETDATE()
			,'System'
			,(
			SELECT @response_id trLogApiXID
				,pengajuan
				,taskIdPolo
				,mtType
				,@responseCode responseCode
				,errorMsg responseMessage
			FROM #RESPONSE_EXEC_KAWAN FOR JSON path, WITHOUT_ARRAY_WRAPPER)
		
			)

		--RAISERROR(@ERRMSG, @ERRSEVERITY, @ERRSTATE)  
		SELECT @response_id = T_MKT_POLO_APILOGRESPONSE_ID
		FROM T_MKT_POLO_APILOGRESPONSE
		WHERE RESPONSE_ID = @responseID

		/*set response api - valid*/
		IF (@apiName = 'Data_Pengajuan_Website_To_Polo')
		BEGIN
			SELECT @pengajuan = pengajuan
				,@taskIdPolo = taskIdPolo
				,@statusPengajuan = statusPengajuan
				,@mtType = mtType
				,@statusProspek = statusProspek
			FROM #RESPONSE_EXEC_KAWAN

			SELECT @response_id trLogApiXID
				,@pengajuan submissionNo
				,@taskIdPolo taskIdPolo
				,@mtType mtType
				,@responseCode responseCode
				,@messageSystemErr responseMessage
		END
		ELSE
		BEGIN
			SELECT @responseCode responseCode
				,@responseMessage responseMessage
				,@messageSystemErr errorMessage
		END
	END CATCH

END




ELSE
BEGIN
	/*insert log response - invalid*/
	SELECT @responseCode = RESPONSE_CODE
		,@responseMessage = RESPONSE_MESSAGE
	FROM M_MKT_POLO_RESPONSECODE
	WHERE RESPONSE_CODE = @errorParamCode

	SET @messageErr = 'Parameter cannot be empty'

	INSERT INTO T_MKT_POLO_APILOGRESPONSE (
		ID_NAME
		,RESPONSE_CODE
		,RESPONSE_MESSAGE
		,ERROR_DESC
		,RESPONSE_DT
		,RESPONSE_ID
		,DTM_CRT
		,USR_CRT
		)
	VALUES (
		@apiName
		,@responseCode
		,@responseMessage
		,@messageErr
		,GETDATE()
		,@responseID
		,GETDATE()
		,'System'		
		)

	SELECT @response_id = T_MKT_POLO_APILOGRESPONSE_ID
	FROM T_MKT_POLO_APILOGRESPONSE
	WHERE RESPONSE_ID = @responseID

	/*set response api - valid*/
	
	SELECT @response_id trLogApiXID
		,pengajuan submissionNo
		,taskIdPolo taskIdPolo
		,mtType mtType
		,@responseCode responseCode
		,errorMsg errMsg
		FROM #RESPONSE_EXEC_KAWAN
	
END
