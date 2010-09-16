BEGIN;
SET client_min_messages TO 'WARNING';

TRUNCATE release_raw CASCADE;
TRUNCATE cdtoc_raw CASCADE;
TRUNCATE track_raw CASCADE;

INSERT INTO release_raw (id, title, artist, added, lastmodified, lookupcount, modifycount, source, barcode, comment) 
            VALUES (1, 'Test Stub', 'Test Artist', '2000-01-01 0:00', '2001-01-01 0:00', 10, 1, 0, '837101029192', 'this is a comment');

INSERT INTO track_raw (release, title, artist, sequence) 
            VALUES (1, 'Track title 1', '', 0);
INSERT INTO track_raw (release, title, artist, sequence) 
            VALUES (1, 'Track title 2', '', 1);

INSERT INTO cdtoc_raw (release, discid, trackcount, leadoutoffset, trackoffset) 
            VALUES (1, 'YfSgiOEayqN77Irs.VNV.UNJ0Zs-', 2, 20000, '{150,10000}');

COMMIT;
