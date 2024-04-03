USE [DbAlgoritma]
GO
/****** Object:  StoredProcedure [dbo].[usp_vedika_algoritma_job_byNoBATB]    Script Date: 02/04/2024 13:49:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- select top 10 * from DatBATerimaBerkas

ALTER PROCEDURE [dbo].[usp_vedika_algoritma_job_byNoBATB_test] @noBATB varchar(30), @PPKPELSEP varchar(8), @FUSER VARCHAR(30)
as
SET XACT_ABORT ON

BEGIN
BEGIN TRY
	set nocount on

	-- 0: baru, 3: gagal
	-- 2: selesai, 1: proses

	-- masuk job status 1, dan 3
	-- 0 ke 1, by klik user
	
    -- 2023/10/02: logika sarpras di non aktif kan

	--if exists(select 1 from [LINKLISTVEDIKA].DbVedika.dbo.DatBATerimaBerkas with(nolock) where NOBATB=@noBATB and (status NOT in ('1','3') or KETPROSES = '[SYS] - Proses Algoritma..')) --secondary
	--BEGIN
	--	-- jika status bukan 1, 3 atau belum proses(keterangan='[SYS] - Proses Algoritma..')
	--	RETURN;
	--END
	--ELSE
	--BEGIN
	-- mulai XXXXX

		--DECLARE @TGLPELAYANAN DATE = (SELECT TGLLAYANAN from [LINKLISTVEDIKA].DbVedika.dbo.DatBATerimaBerkas with(nolock) where NOBATB=@noBATB) --secondary
		---- rs khusus
		--declare @is_RS_khusus int = 0
		--set @is_RS_khusus = (select top 1 1 from fn_RefPPKKhusus(@PPKPELSEP))

		--DECLARE @msg VARCHAR(500)
		---- jika klaim rs khusus, maka filtrasi rs khusus harus dilakukan sbelum menjalankan ALGORTIMA
		--IF @is_RS_khusus = 1 and NOT exists  (select top 1 1 from [LINKLISTVEDIKA].DbVedika.dbo.DatDoubleKlaim with(nolock) where PPKPELSEP=@PPKPELSEP and TAHUN=YEAR(@TGLPELAYANAN) and BULAN=MONTH(@TGLPELAYANAN) and IDDOUBLE = 32) --secondary
		--BEGIN
			
		--	-- RAISERROR ('Filtrasi RS Khusus Belum dijalankan!', 18,1)
		--	-- [LINKSERVER_P]

		--	update DbVedika.dbo.DatBATerimaBerkas set status=3, TGLPROSES=CURRENT_TIMESTAMP, KETPROSES='Gagal Proses, Filtrasi RS Khusus Belum dijalankan!' where NOBATB=@noBATB  --primary
		--	insert into DbVedika.dbo.ALGORITMA_JOB_Error_LOG(NOBATB,KDPPK,LOG_LOGIKA,ERRORMSG,FDATE) SELECT @noBATB, @PPKPELSEP, 'FILTRASI RS KHUSUS', 'Gagal Proses, Filtrasi RS Khusus Belum dijalankan!', CURRENT_TIMESTAMP --primary
		--	RETURN;
		--END

		-- set sedang proses, status 1
		-- [LINKSERVER_P]
		--update DbVedika.dbo.DatBATerimaBerkas set status=1, TGLPROSES=CURRENT_TIMESTAMP, KETPROSES='[SYS] - Proses Algoritma..' where NOBATB=@noBATB and [STATUS] in ('1','3') --primary

		BEGIN TRANSACTION

		--- ALGORITMA BEGIN

			Declare @kdkr VARCHAR(2),@tgllayan date
			declare @NOSEPSel table(
				id int IDENTITY(1,1) NOT NULL,
				NOSEP VARCHAR(19) NOT NULL
			);

			SELECT @kdkr=KDKR FROM [LINKLISTVEDIKA].DbVedika.dbo.REFPPK a with(nolock)   --secondary
			inner join [LINKLISTVEDIKA].DbVedika.dbo.refkc b with(nolock) on b.KDKC=a.KDKC --secondary
			WHERE KDPPK=@PPKPELSEP

			declare @tmpidfile table(idfile varchar(50),tgllayanan DATE)
			insert into @tmpidfile(idfile,tgllayanan)
			select a.IDFILE,b.TGLLAYANAN from [LINKLISTVEDIKA].DbVedika.dbo.DatBATerimaBerkasDetail a with(nolock)  --secondary
			inner join [LINKLISTVEDIKA].DbVedika.dbo.DatBATerimaBerkas b with(nolock)  on b.NOBATB=a.NOBATB
			where a.NOBATB=@NOBATB

			select top 1 @tgllayan=tgllayanan from @tmpidfile
			-- select @tgllayan

			insert into @NOSEPSel
			SELECT a.NOSEP
			from [LINKLISTVEDIKA].DbVedika.dbo.DATVERIFIKASI a with(nolock)  --secondary
			inner join @tmpidfile b on b.idfile=a.IDFILE

			--tampung dan ambil di datverifikasi

			declare @tempdbver table(NOSEP varchar(19) index idx1 nonclustered,PPKPELSEP VARCHAR(8),NOKAPST VARCHAR(13), 
			TGLSEP DATE,TGLPLGSEP DATE,POLITUJSEP VARCHAR(3),
			JNSPELSEP VARCHAR(1),KDINACBG VARCHAR(20),KDJNSPULANG VARCHAR(2),LOS INT,
			KDSD VARCHAR(15),KDSA VARCHAR(15),
			KDSP VARCHAR(15),KDSI VARCHAR(15), KDSR VARCHAR(15), FLAGPRSKLAIMSEP VARCHAR(3), PERIKSA VARCHAR(3)
			)

			-- insert into @tempdbver
			-- SELECT ver.nosep, ver.ppkpelsep, ver.NOKAPST, ver.tglsep, ver.TGLPLGSEP, ver.POLITUJSEP,
			-- 	ver.JNSPELSEP, ver.KDCBGS, ver.KDJNSPULANG, ver.los, ver.kdsd, ver.kdsa, ver.kdsp, ver.kdsi, ver.kdsr, ver.FLAGPRSKLAIMSEP, ver.PERIKSA
			--  from datverifikasi ver with(nolock) 
			-- 	inner join @NOSEPSel sel on ver.nosep = sel.nosep

			DECLARE @TableTampungAlgoritma dbo.[TableTampungAlgoritma];

			Declare @Rowcount INT = 1;
			DECLARE @id_control INT
			DECLARE @batchSize INT
			SET @batchSize = 100000 --tambahan
			SET @id_control = 0 --tambahan
			WHILE (@Rowcount > 0)  
			BEGIN
				INSERT INTO @TableTampungAlgoritma 
				(
					NOSEP,TGLSEP,TGLPLGSEP,NOKAPST,PPKPELSEP ,POLITUJSEP,JNSPELSEP,
					KDINACBG,KDJNSPULANG,LOS,KDSD,KDSA,KDSP,KDSI,KDSR
				) 	
				select  
				a.NOSEP,a.TGLSEP,a.TGLPLGSEP,a.NOKAPST,a.PPKPELSEP, a.POLITUJSEP,a.JNSPELSEP,
				a.KDCBGS,a.KDJNSPULANG,a.LOS,a.KDSD,a.KDSA,a.KDSP,a.KDSI,a.KDSR
				from [LINKLISTVEDIKA].DbVedika.dbo.datverifikasi a with(nolock)  --secondary
				inner join @NOSEPSel d on a.NOSEP = d.nosep	 --tambahan
				and d.id > @id_control and d.id <= @id_control + @batchSize --tambahan

				SET @Rowcount = @@ROWCOUNT;
				SET @id_control = @id_control + @batchSize --tambahan 
			end
			
			DECLARE @tgl_Proses date = CURRENT_TIMESTAMP

			declare @TB_TMP_DOUBLEKLAIM TABLE(
												ppkpelsep varchar(8) index idx1 nonclustered
												, iddouble int, bulan int, tahun int, tglproses DATETIME, tglproses_ri DATETIME
												, jmlRow int, jmlRow_Ri int, totData int, totData_Ri int
												, sep varchar(max), sep_ri varchar(max)
												, fuser varchar(30), fdate DATETIME 
											)

			-- select * from @tmpidfile
			-- select * from @TableTampungAlgoritma

			DECLARE @LOG_LOGIKA varchar(8000) =  '';
			print '[ >> ALGORITMA VERIFIKASI: START ] - NOBA TB :' + @noBATB + N',  PPK : ' + @PPKPELSEP


			SET @LOG_LOGIKA = '[ | ID LOGIKA 1 : RJ-RJ ] - NOBA TB :' + @noBATB + N',  PPK : ' + @PPKPELSEP
			print @LOG_LOGIKA
			-- ID: 1
			INSERT INTO @TB_TMP_DOUBLEKLAIM exec USP_ALGORITMA_DOUBLEKLAIM_RJ_RJ @PPKPELSEP,@tgllayan,@TableTampungAlgoritma

			SET @LOG_LOGIKA = '[ | ID LOGIKA 2 : Ri-RJ ] - NOBA TB :' + @noBATB + N',  PPK : ' + @PPKPELSEP
			print @LOG_LOGIKA
			-- ID: 2
			INSERT INTO @TB_TMP_DOUBLEKLAIM exec USP_ALGORITMA_DOUBLEKLAIM_Ri_RJ @PPKPELSEP,@tgllayan,@TableTampungAlgoritma

			SET @LOG_LOGIKA = '[ | ID LOGIKA 15 : Potensi KLL Traumatik ] - NOBA TB :' + @noBATB + N',  PPK : ' + @PPKPELSEP
			print @LOG_LOGIKA
			-- ID: 15
			INSERT INTO @TB_TMP_DOUBLEKLAIM exec USP_ALGORITMA_POTENSI_KLL_TRAUMATIK @PPKPELSEP,@tgllayan,@TableTampungAlgoritma

			-- SET @LOG_LOGIKA = '[ | ID LOGIKA 22 : Sarana Prasarana ] - NOBA TB :' + @noBATB + N',  PPK : ' + @PPKPELSEP
			-- print @LOG_LOGIKA
			-- ID: 22
			-- INSERT INTO @TB_TMP_DOUBLEKLAIM exec USP_ALGORITMA_SARANA_PRASARANA @PPKPELSEP,@tgllayan,@TableTampungAlgoritma

			SET @LOG_LOGIKA = '[ | ID LOGIKA 25 : Double Klaim Covid ] - NOBA TB :' + @noBATB + N',  PPK : ' + @PPKPELSEP
			print @LOG_LOGIKA
			-- ID: 25
			INSERT INTO @TB_TMP_DOUBLEKLAIM exec USP_ALGORITMA_DOUBLEKLAIMJKNCOVID @PPKPELSEP,@tgllayan,@TableTampungAlgoritma

			SET @LOG_LOGIKA = '[ | ID LOGIKA 26 : Coinsiden JKN Covid ] - NOBA TB :' + @noBATB + N',  PPK : ' + @PPKPELSEP
			print @LOG_LOGIKA
			-- ID: 26
			INSERT INTO @TB_TMP_DOUBLEKLAIM exec USP_ALGORITMA_COINSIDEN_JKNCOVID @PPKPELSEP,@tgllayan,@TableTampungAlgoritma
				
			SET @LOG_LOGIKA = '[ | ID LOGIKA 27 : LOS <= 2 Hari ] - NOBA TB :' + @noBATB + N',  PPK : ' + @PPKPELSEP
			print @LOG_LOGIKA
			-- ID: 27
			INSERT INTO @TB_TMP_DOUBLEKLAIM exec USP_ALGORITMA_LOS_2_HARI @PPKPELSEP,@tgllayan,@TableTampungAlgoritma

			SET @LOG_LOGIKA = '[ | ID LOGIKA 28 : RJ Berulang ] - NOBA TB :' + @noBATB + N',  PPK : ' + @PPKPELSEP
			print @LOG_LOGIKA
			-- ID: 28
			INSERT INTO @TB_TMP_DOUBLEKLAIM exec USP_ALGORITMA_RJ_BERULANG @PPKPELSEP,@tgllayan,@TableTampungAlgoritma

			SET @LOG_LOGIKA = '[ | ID LOGIKA 29 : SEP Internal vs Jadwal ] - NOBA TB :' + @noBATB + N',  PPK : ' + @PPKPELSEP
			print @LOG_LOGIKA
			-- ID: 29
			INSERT INTO @TB_TMP_DOUBLEKLAIM exec USP_ALGORITMA_INTERNAL_ADA_JADWAL @PPKPELSEP,@tgllayan,@TableTampungAlgoritma
				
			SET @LOG_LOGIKA = '[ | ID LOGIKA 30 : RJ IRM/FIS Berulang ] - NOBA TB :' + @noBATB + N',  PPK : ' + @PPKPELSEP
			print @LOG_LOGIKA
			-- ID: 30
			INSERT INTO @TB_TMP_DOUBLEKLAIM exec USP_ALGORITMA_RJ_REHABMEDIS_BERULANG_MINGGUAN @PPKPELSEP,@tgllayan,@TableTampungAlgoritma

			SET @LOG_LOGIKA = '[ | ID LOGIKA 31 : RJ HDL Berulang ] - NOBA TB :' + @noBATB + N',  PPK : ' + @PPKPELSEP
			print @LOG_LOGIKA
			-- ID: 31
			INSERT INTO @TB_TMP_DOUBLEKLAIM exec USP_ALGORITMA_RJ_HD_BERULANG_MINGGUAN @PPKPELSEP,@tgllayan,@TableTampungAlgoritma

			-- if @is_RS_khusus = 1
			-- BEGIN

			-- 	SET @LOG_LOGIKA = '[ | ID LOGIKA 32 : RS KHUSUS ] - NOBA TB :' + @noBATB + N',  PPK : ' + @PPKPELSEP
			-- 	print @LOG_LOGIKA
			-- 	-- ID: 32
			-- 	exec USP_ALGORITMA_RSKHUSUS @PPKPELSEP, @tgllayan, @TableTampungAlgoritma, @FUSER

			-- END
			
			print '<< ] ALGORITMA VERIFIKASI: END ] - NOBA TB :' + @noBATB + N',  PPK : ' + @PPKPELSEP

		-- >> proses

		DECLARE @BULAN int, @TAHUN int, @APROVED int = 1
		SELECT @BULAN = MONTH(TGLLAYANAN), @TAHUN= YEAR(TGLLAYANAN) from [LINKLISTVEDIKA].DbVedika.dbo.DatBATerimaBerkas with(nolock) WHERE NOBATB=@NOBATB and PPKPELSEP=@PPKPELSEP --secondary

		update @TB_TMP_DOUBLEKLAIM set fuser = @FUSER

		-- delete db
		-- from DatDoubleKlaim db with(nolock) 
		-- 		inner JOIN @TB_TMP_DOUBLEKLAIM tmp on db.PPKPELSEP=tmp.ppkpelsep and db.BULAN=tmp.bulan AND db.TAHUN=tmp.tahun
		-- 	WHERE 
		-- 		db.IDDOUBLE in (1, 2, 15, 22, 25, 26, 27, 28, 29, 30, 31)

		-- langsung hapus ajah
		delete DbVedika.dbo.DatDoubleKlaim --primary
			WHERE PPKPELSEP = @PPKPELSEP and BULAN = @BULAN and TAHUN = @TAHUN
				and IDDOUBLE in (1, 2, 15, 22, 25, 26, 27, 28, 29, 30, 31)

		insert into DbVedika.dbo.DatDoubleKlaim(  --primary
				[PPKPELSEP],[IDDOUBLE],[BULAN],[TAHUN]
				,[TGLPROSES],[TGLPROSES_RI],[JMLROW],[JMLROW_RI]
				,[TOTALDATA],[TOTALDATA_RI]
				,[SEP],[SEP_RI],[FUSER],[FDATE]
		)
		select [PPKPELSEP],[IDDOUBLE],[BULAN],[TAHUN]
				,[TGLPROSES],[TGLPROSES_RI],[JMLROW],[JMLROW_RI]
				,[totData],[totData_Ri]
				,[SEP],[SEP_RI],[FUSER],[FDATE] from @TB_TMP_DOUBLEKLAIM

		-- >> update flag verifikasi
		DECLARE @KD_LOGIKA TABLE (nomor int NOT NULL identity(1,1), kdlogika int)
		DECLARE @TMP_Flag_Verifikasi_temp TABLE (nosep varchar(19) index idx1 nonclustered, FLAGPRSKLAIMSEP varchar(4) index idx2 nonclustered, pernahDiajukan int default 0)
		DECLARE @TMP_Flag_Verifikasi TABLE (nosep varchar(19) index idx1 nonclustered, FLAGPRSKLAIMSEP varchar(4) index idx2 nonclustered, pernahDiajukan int default 0)

		INSERT into @KD_LOGIKA (kdlogika)
			SELECT tmp.iddouble as kdlogika from @TB_TMP_DOUBLEKLAIM tmp 
		GROUP BY tmp.iddouble

		-- loop kdlogika, ambil nosep dan flagprsklaimsep per kdlogika
		DECLARE @loop int = 1
		DECLARE @loopMax int = (select count(1) from @KD_LOGIKA)
		DECLARE @loopCurrentLogika int = 0
		
		WHILE (@loop <= @loopMax)
		BEGIN
			set @loopCurrentLogika = (select kdlogika from @KD_LOGIKA where nomor=@loop)

			if @loopCurrentLogika > 0
				BEGIN
					INSERT into @TMP_Flag_Verifikasi_temp(nosep)
					select splitdata as nosep 
						from dbo.fnSplitString((select sep from @TB_TMP_DOUBLEKLAIM where iddouble=@loopCurrentLogika),',')
				END

			set @loop += 1
			set @loopCurrentLogika = 0

			-- endof loop, get flag dan cek apakah pernah di ajukan sebelumnya
			if @loop > @loopMax
			BEGIN

				INSERT into @TMP_Flag_Verifikasi
					select distinct * from @TMP_Flag_Verifikasi_temp
				-- ambil flag
				UPDATE tmp
					SET tmp.FLAGPRSKLAIMSEP=ver.FLAGPRSKLAIMSEP
				from [LINKLISTVEDIKA].DbVedika.dbo.Datverifikasi ver with(nolock) --secondary
					inner JOIN @TMP_Flag_Verifikasi tmp on ver.NOSEP=tmp.nosep
				
				delete @TMP_Flag_Verifikasi_temp
				
				-- cek apakah nosep pernah di ajukan sebelumnya, khusus utk flag 6, 11
				-- UPDATE tmp
				-- 	SET tmp.pernahDiajukan = 1
				-- from @TMP_Flag_Verifikasi tmp 
				-- 	where
				-- 		tmp.FLAGPRSKLAIMSEP in ('6','11')
				-- 		and dbo.UFN_VEDIKA_ALGORITMA_NOSEP_PERNAH_DIAJUKAN(tmp.NOSEP)=1
			END
			
		END

		-- # 115/MKU/0523
		-- Klaim yang tersaring pada Algoritma Verifikasi berstatus “Belum Diverifikasi / null ”

		-- Semua Hasil Luaran dari Algoritma Verifikasi berstatus “Belum Diverifikasi / null” baik pada pengajuan ulang dengan status “Pending” maupun “Dispute”.
		-- Khusus untuk klaim yang diajukan ulang terdapat flagging “Pending” atau “Dispute”.
		-- logik deteksi pengajuan ulang nosep di fn : UFN_VEDIKA_ALGORITMA_NOSEP_PERNAH_DIAJUKAN
		-- flag pending/dispute pada tabel DatBATerimaBerkas_Algoritma

		-- simpan flagging pending, dispute khusus sep yg diajukan > 1 berdasarkan DatVerifikasi_Diva dengan pengajuan = 1
		DELETE FROM DbVedika.dbo.DatBATerimaBerkas_Algoritma where NOBATB=@noBATB and KDPPK=@PPKPELSEP --primary
		
		DECLARE @CUR_STAMP datetime = CURRENT_TIMESTAMP

		INSERT INTO DbVedika.[dbo].[DatBATerimaBerkas_Algoritma]([NOBATB],[KDPPK],[NOSEP],[FLAGPRSKLAIMSEP],[isPENDING],[isDISPUTE],[isPernahDiajukan],[FUSER],[FDATE]) --primary
		SELECT DISTINCT @noBATB, @PPKPELSEP, ver.NOSEP
			, ver.FLAGPRSKLAIMSEP
			,IIF(ver.FLAGPRSKLAIMSEP='6',1,0) as isPENDING
			,IIF(ver.FLAGPRSKLAIMSEP='11',1,0) as isDISPUTE
			-- ,IIF(tmp.pernahDiajukan=1,1,0) as isPernahDiajukan
			-- ,IIF(ver.FLAGPRSKLAIMSEP in ('6','11') and dbo.UFN_VEDIKA_ALGORITMA_NOSEP_PERNAH_DIAJUKAN(ver.NOSEP)=1,1,0) as isPernahDiajukan
			,IIF(dbo.UFN_VEDIKA_ALGORITMA_NOSEP_PERNAH_DIAJUKAN(ver.NOSEP)=1,1,0) as isPernahDiajukan
			, @FUSER, @CUR_STAMP
		from @TableTampungAlgoritma hasil 
			inner join [LINKLISTVEDIKA].DbVedika.dbo.Datverifikasi ver with(nolock) on hasil.nosep=ver.NOSEP --secondary
			-- left join @TMP_Flag_Verifikasi tmp on hasil.nosep=tmp.nosep
		-- WHERE
		-- 	dbo.UFN_VEDIKA_ALGORITMA_NOSEP_PERNAH_DIAJUKAN(ver.NOSEP)=1

		-- select * from DatBATerimaBerkas_Algoritma WITH(nolock) where flagprsklaimsep in (6, 11) order by fdate desc
		-- select * from DatBATerimaBerkas_Algoritma dt WITH(nolock) 
		-- where 
		-- 	flagprsklaimsep in (6, 11)
		-- 	and dbo.UFN_VEDIKA_ALGORITMA_NOSEP_PERNAH_DIAJUKAN(dt.NOSEP)=1

		-- insert ke history

		-- select top 100 * from Datverifikasi where nosep='0901R0060120V000524'
		-- select top 100 * from Datverifikasi_Detail order by fdate desc
		-- select top 100 * from Datverifikasi_Diva order by fdate desc
		-- select top 10 * from DatFile_Diva_Header
		-- select top 10 * from DatFile_Diva_Detail
		-- select top 10 divaDet.* from Datverifikasi_Diva verD 
		-- inner join DatFile_Diva_Detail divaDet on verD.IDFILE_DIVA=divaDet.IDFILE 
		-- inner join DatFile_Diva_Header divaHead on divaDet.IDFILE_DIVA=divaHead.IDFILE_DIVA 
		
		INSERT INTO DbVedika.dbo.Datverifikasi_Detail([NOBATB],[KDPPK] ,[NOSEP],[FLAGPRSKLAIMSEP],[FLAGPRSKLAIMSEP_KETERANGAN],[JENISDISPUTE],[FUSER],[FDATE]) --primary
		SELECT @noBATB, @PPKPELSEP, ver.NOSEP, diva.FLAGPRSKLAIMSEP,
				CONCAT(
						'[DIVA] ',
						(	CASE 
								WHEN divaHead.PENGAJUAN=1 THEN 'Tidak Diajukan' 
								WHEN divaHead.PENGAJUAN=2 THEN 'Diajukan' 
								ELSE '--' END
							)
						) as Keterangan,
				null as jenisdispute, ISNULL(divaHead.FUSER, divaDet.FUSER) as fuser, ISNULL(divaHead.TGLPROSES, divaHead.FDATE) as fdate
			from 
				[LINKLISTVEDIKA].DbVedika.dbo.Datverifikasi ver with(nolock) --secondary
				inner join @TableTampungAlgoritma tmp on ver.NOSEP=tmp.NOSEP
				inner join [LINKLISTVEDIKA].DbVedika.dbo.DatVerifikasi_Diva diva with(nolock) on ver.NOSEP=diva.NOSEP --secondary
				inner join [LINKLISTVEDIKA].DbVedika.dbo.DatFile_Diva_Detail divaDet with(nolock) on diva.IDFILE_DIVA=divaDet.IDFILE  --secondary
				inner join [LINKLISTVEDIKA].DbVedika.dbo.DatFile_Diva_Header divaHead with(nolock) on divaDet.IDFILE_DIVA=divaHead.IDFILE_DIVA  --secondary
				WHERE
					ver.FLAGPRSKLAIMSEP in ('4','6','11')
					and ver.PERIKSA NOT in (90, 99)

		-- update semua flag menjadi 10
		update ver 
			set 
				-- ver.FLAGPRSKLAIMSEP = IIF( hasil.pernahDiajukan = 0, '10', ver.FLAGPRSKLAIMSEP )
				ver.FLAGPRSKLAIMSEP = '10'
				, ver.LDate = @CUR_STAMP , ver.LUser = @FUSER
			from DbVedika.dbo.Datverifikasi ver inner join @TMP_Flag_Verifikasi hasil on ver.NOSEP=hasil.NOSEP --primary
				WHERE
					ver.FLAGPRSKLAIMSEP in ('1','4','6','10','11') 
					and PERIKSA NOT in (90, 99)

		INSERT INTO DbVedika.dbo.Datverifikasi_Detail([NOBATB],[KDPPK] ,[NOSEP],[FLAGPRSKLAIMSEP],[FLAGPRSKLAIMSEP_KETERANGAN],[JENISDISPUTE],[FUSER],[FDATE]) --primary
		SELECT @noBATB, @PPKPELSEP, ver.NOSEP, '10', '[ALGORITMA]' as Keterangan, null as jenisdispute, @FUSER, @CUR_STAMP
			from [LINKLISTVEDIKA].DbVedika.dbo.Datverifikasi ver inner join @TMP_Flag_Verifikasi hasil on ver.NOSEP=hasil.NOSEP --secondary
				WHERE
					ver.FLAGPRSKLAIMSEP='10'
					and PERIKSA NOT in (90, 99)

		-- update flag rules DIVA tanpa simpan ke riwayat
		-- jika kena algo maka ikut algo, hanya untuk yg gak kena algo
		UPDATE diva
			SET diva.FLAGPRSKLAIMSEP='10'
		FROM @TableTampungAlgoritma allsep 
		INNER JOIN DbVedika.dbo.Datverifikasi diva WITH(nolock) on allsep.NOSEP=diva.NOSEP --primary
		LEFT JOIN @TMP_Flag_Verifikasi hasil ON allsep.NOSEP=hasil.nosep
		WHERE
			hasil.nosep is NULL
			AND diva.FLAGPRSKLAIMSEP in ('6', '11')
			AND diva.PERIKSA NOT in (90, 99)

		-- update semua flag menjadi 6 periksa 10
		-- untuk klaim rs khusus yang terkena algoritma (flag nya menjadi 10)
		-- agar terbaca pada filtrasi rs khusus
		
		-- INSERT INTO Datverifikasi_Detail([NOBATB],[KDPPK] ,[NOSEP],[FLAGPRSKLAIMSEP],[FLAGPRSKLAIMSEP_KETERANGAN],[JENISDISPUTE],[FUSER],[FDATE])
		-- SELECT @noBATB, @PPKPELSEP, ver.NOSEP, '6', '[SISTEM] - Ketidaksesuaian Pengajuan Klaim RS KHUSUS' as Keterangan, null as jenisdispute, @FUSER, @CUR_STAMP
		-- 	from Datverifikasi ver inner join @TMP_Flag_Verifikasi hasil on ver.NOSEP=hasil.NOSEP
		-- 		WHERE
		-- 			ver.FLAGPRSKLAIMSEP = '10'
		-- 			and PERIKSA = 90

		update ver 
			set 
				-- ver.FLAGPRSKLAIMSEP = IIF( hasil.pernahDiajukan = 0, '10', ver.FLAGPRSKLAIMSEP )
				ver.FLAGPRSKLAIMSEP = '6'
				, ver.LDate = @CUR_STAMP , ver.LUser = @FUSER
			from DbVedika.dbo.Datverifikasi ver inner join @TMP_Flag_Verifikasi hasil on ver.NOSEP=hasil.NOSEP --primary
				WHERE
					ver.FLAGPRSKLAIMSEP = '10'
					and PERIKSA = 90

		--- << ENDOF ALGORITMA

		-- print '[ >> ALGORITMA VERIFIKASI: ] - NOBA TB :' + @noBATB + N',  PPK : ' + @PPKPELSEP

		-- select * from @tempdbver
		-- select * from @TMP_Flag_Verifikasi
		-- select * from @TableTampungAlgoritma
		-- select * from @TB_TMP_DOUBLEKLAIM
		-- select * from @KD_LOGIKA
		-- select * from @TMP_Flag_Verifikasi

		DELETE from @TableTampungAlgoritma
		DELETE from @TB_TMP_DOUBLEKLAIM
		DELETE from @TMP_Flag_Verifikasi

		-- set selesai proses, status 2
		update DbVedika.dbo.DatBATerimaBerkas set status=2, TGLSELESAI=CURRENT_TIMESTAMP, KETPROSES='Selesai Proses' where NOBATB=@noBATB and [STATUS] in ('1','3') --primary
		-- bugifx anomali data
		-- terjadi ketika flag diva vs flag datverifikasi tidak sync
		EXEC usp_vedika_algoritma_svd_Anomali_1 @noBATB, @PPKPELSEP, @BULAN, @TAHUN, @APROVED

		-- // endof bugifx anomali data


	-- endof XXXXX
	END
	COMMIT
END TRY
BEGIN CATCH

	DELETE from @TableTampungAlgoritma
	DELETE from @TB_TMP_DOUBLEKLAIM
	DELETE from @TMP_Flag_Verifikasi

	DECLARE @ErrorMessage NVARCHAR(4000);
	SELECT @ErrorMessage = ERROR_MESSAGE();
	-- log
	-- insert into ALGORITMA_JOB_Error_LOG(NOBATB,KDPPK,LOG_LOGIKA,ERRORMSG,FDATE) SELECT @noBATB, @PPKPELSEP, LEFT(@LOG_LOGIKA,1000), LEFT(@ErrorMessage,1000), CURRENT_TIMESTAMP
	PRINT '## ERROR PROSES DATA : ' + LEFT(@LOG_LOGIKA,1000)

	RAISERROR (@ErrorMessage, 18,1)
	ROLLBACK
	-- set error proses, status 3
	update DbVedika.dbo.DatBATerimaBerkas set status=3, TGLPROSES=CURRENT_TIMESTAMP, KETPROSES='Gagal Proses, ' + LEFT(@ErrorMessage, 100) where NOBATB=@noBATB --primary

END CATCH
END
