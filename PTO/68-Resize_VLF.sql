/***** Step-step memperbaiki VLF untuk database dengan FULL recovery model *****/
-- Mohon di dibaca dan cek dengan teliti script dibawah, di test dulu environment non-prod
-- Pastikan tag/placeholder <text> diganti dengan value yg sesuai, contoh:
-- <database_name> = AdventureWorks
-- <logical_name> = AdventureWorks_Log
-- <YYYYMMDD> = 20240712
-- <HHMMSS> = 011500
-- NOTE: Script dijalankan satu-per-satu, jangan sekaligus.
/*******************************************************************************/

-- STEP-01: Catat nama database dan nama log file yang akan di shrink dengan query berikut:

USE master;
GO
SELECT db_name(database_id) as dbname, type_desc, name as logicalname, ROUND((size*8)/1024,0) as sizeMB
FROM sys.master_files
WHERE type_desc = 'LOG';
GO

-- STEP-02: Tunggu sampai jumlah sesi atau transaksi minimal, check di acitivity monitor atau sp_whoisactive
-- Kemudian masuk ke dalam konteks database yg dipilih dan jalankan SHRINKFILE
-- Ganti dulu tag <database_name> dan <logical_name> di dalam script dibawah sebelum eksekusi

USE [<database_name>];
GO
DBCC SHRINKFILE (N'<logical_name>', 1, TRUNCATEONLY);
GO

-- STEP-03: CEK apakah tlog file sudah mengecil dengan query berikut:

SELECT name, (size*8)/1024 AS log_MB FROM dbo.sysfiles WHERE (64 & status) = 64
GO

-- STEP-04: Jika log file belum cukup kecil, lakukan backup log.
-- Ganti dulu tag di dalam script sesuai dengan text yang benar

BACKUP LOG [<database_name>] TO DISK = '<path>\<database_name>_<YYYYMMDD>_<HHMMSS>.trn';

-- Ulangi STEP-02, STEP-03, STEP-04, sampai log size mengecil 
-- jika memungkinkan hingga sekitar 1 MB, atau paling tidak dibawah 1 GB.
-- STEP-05: Jika sudah cukup kecil size log file, maka kita bisa resize log file sesuai best practice:
-- Opsi 1 untuk database kecil, initial size = 2048MB, autogrow = 128MB
-- Opsi 2 untuk database sedang, initial size = 4096MB, autogrow = 256MB
-- Opsi 3 untuk database besar, initial size = 8192MB, autogrow = 512MB
-- Opsi 4 untuk database VLDB, initial size = 16384MB, autogrow = 1024MB

USE master;
GO
ALTER DATABASE [<database_name>] MODIFY FILE ( NAME = N'<logical_name>', SIZE = 8192MB , FILEGROWTH = 512MB );
GO
