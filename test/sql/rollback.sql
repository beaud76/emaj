-- rollback.sql : test updates log, emaj_rollback_group(), emaj_logged_rollback_group(),
--                emaj_rollback_groups(), and emaj_logged_rollback_groups() functions.
--                also test emaj_cleanup_rollback_state(), and emaj_rollback_activity().
--
-----------------------------
-- rollback nothing tests
-----------------------------

-- group or groups is NULL
select emaj.emaj_rollback_group(NULL,NULL);
select emaj.emaj_logged_rollback_group(NULL,NULL);

select emaj.emaj_rollback_groups(NULL,NULL);
select emaj.emaj_logged_rollback_groups(NULL,NULL);

-- group is unknown in emaj_group_def
select emaj.emaj_rollback_group('unknownGroup',NULL);
select emaj.emaj_logged_rollback_group('unknownGroup',NULL);

select emaj.emaj_rollback_groups('{"unknownGroup"}',NULL);
select emaj.emaj_logged_rollback_groups('{"unknownGroup","myGroup1"}',NULL);
begin;
  select emaj.emaj_start_group('myGroup1','');
  select emaj.emaj_rollback_groups('{"myGroup1","unknownGroup"}','EMAJ_LAST_MARK');
rollback;

-- group not in logging state
select emaj.emaj_rollback_group('myGroup1','EMAJ_LAST_MARK');
select emaj.emaj_rollback_group('myGroup2','EMAJ_LAST_MARK');

select emaj.emaj_logged_rollback_group('myGroup1','EMAJ_LAST_MARK');
select emaj.emaj_logged_rollback_group('myGroup2','EMAJ_LAST_MARK');

select emaj.emaj_rollback_groups('{"myGroup1","myGroup2"}',NULL);
begin;
  select emaj.emaj_start_group('myGroup1','');
  select emaj.emaj_logged_rollback_groups('{"myGroup1","myGroup2"}','EMAJ_LAST_MARK');
rollback;

-- start groups and set some marks
select emaj.emaj_start_group('myGroup1','Mark11');
select emaj.emaj_start_group('myGroup2','Mark21');

select emaj.emaj_set_mark_group('myGroup1','Different_Mark');
select emaj.emaj_set_mark_group('myGroup2','Different_Mark');

-- log tables are empty
select count(*) from emaj.myschema1_mytbl1_log;
select count(*) from emaj.myschema1_mytbl2_log;
select count(*) from emajb.myschema1_mytbl2b_log;
select count(*) from "emajC"."myschema1_myTbl3_log";
select count(*) from emaj.myschema1_mytbl4_log;
select count(*) from emaj.myschema2_mytbl1_log;
select count(*) from emaj.myschema2_mytbl2_log;
select count(*) from "emajC"."myschema2_myTbl3_log";
select count(*) from emaj.myschema2_mytbl4_log;

-- unknown mark name
select emaj.emaj_rollback_group('myGroup1',NULL);
select emaj.emaj_rollback_group('myGroup1','DummyMark');

select emaj.emaj_logged_rollback_group('myGroup1',NULL);
select emaj.emaj_logged_rollback_group('myGroup1','DummyMark');

select emaj.emaj_rollback_groups('{"myGroup1","myGroup2",""}',NULL);
select emaj.emaj_rollback_groups('{"myGroup1","myGroup2",NULL}',NULL);
select emaj.emaj_rollback_groups('{"myGroup1","myGroup2"}','DummyMark');

select emaj.emaj_logged_rollback_groups('{"myGroup1","myGroup2","myGroup2"}',NULL);
select emaj.emaj_logged_rollback_groups('{"myGroup1","myGroup2"}','Mark11');

-- mark name referencing different points in time
select emaj.emaj_rollback_groups('{"myGroup1","myGroup2"}','Different_Mark');

-- attemp to rollback an 'audit_only' group
select emaj.emaj_rollback_group('phil''s group#3",','EMAJ_LAST_MARK');
select emaj.emaj_logged_rollback_group('phil''s group#3",','M1_audit_only');

-- attemp to rollback to a stop mark
begin;
  select emaj.emaj_stop_group('myGroup1');
  select emaj.emaj_start_group('myGroup1','StartMark',false);
  select emaj.emaj_rename_mark_group('myGroup1',(select emaj.emaj_get_previous_mark_group('myGroup1','StartMark')), 'GeneratedStopMark');
  select emaj.emaj_rollback_group('myGroup1','GeneratedStopMark');
rollback;

-- missing application table and mono-group rollback
begin;
  drop table mySchema2."myTbl3" cascade;
  select emaj.emaj_rollback_group('myGroup2','Mark21');
rollback;
begin;
  drop table mySchema2."myTbl3" cascade;
  select emaj.emaj_logged_rollback_group('myGroup2','Mark21');
rollback;

-- should be OK, with different cases of dblink status
-- hide dblink_connect functions
alter function public.dblink_connect_u(text,text) rename to renamed_dblink_connect_u;
alter function public.dblink_connect_u(text) rename to renamed_dblink_connect_u;
select emaj.emaj_rollback_group('myGroup1','EMAJ_LAST_MARK');
select emaj.emaj_rollback_group('myGroup2','Mark21');
alter function public.renamed_dblink_connect_u(text,text) rename to dblink_connect_u;
alter function public.renamed_dblink_connect_u(text) rename to dblink_connect_u;

-- dblink_connect not in path
set search_path='emaj';
select emaj.emaj_logged_rollback_group('myGroup1','EMAJ_LAST_MARK');
select emaj.emaj_logged_rollback_group('myGroup2','Mark21');
reset search_path;

select emaj.emaj_set_mark_groups('{"myGroup1","myGroup2"}','Mark1B');

-- no user/password defined in emaj_param
select emaj.emaj_rollback_groups('{"myGroup1","myGroup2"}','EMAJ_LAST_MARK');
-- bad user/password defined in emaj_param
insert into emaj.emaj_param (param_key, param_value_text) 
  values ('dblink_user_password','user=<user> password=<password>');
select emaj.emaj_rollback_groups('{"myGroup1","myGroup2"}','Mark1B');

-- dblink connection should now be ok (missing right on dblink functions is tested in adm1.sql)
update emaj.emaj_param set param_value_text = 'user=postgres password=postgres' 
  where param_key = 'dblink_user_password';
select emaj.emaj_logged_rollback_groups('{"myGroup1","myGroup2"}','EMAJ_LAST_MARK');
select emaj.emaj_logged_rollback_groups('{"myGroup1","myGroup2"}','Mark1B');

-- missing application table and multi-groups rollback
begin;
  drop table mySchema2."myTbl3" cascade;
  select emaj.emaj_rollback_groups('{"myGroup1","myGroup2"}','Mark1B');
rollback;
begin;
  drop table mySchema2."myTbl3" cascade;
  select emaj.emaj_logged_rollback_groups('{"myGroup1","myGroup2"}','Mark1B');
rollback;

-- restart groups
select emaj.emaj_stop_groups('{"myGroup1","myGroup2"}');
select emaj.emaj_start_group('myGroup1','Mark11');
select emaj.emaj_start_group('myGroup2','Mark21');

-----------------------------
-- log phase #1 with 2 unlogged rollbacks
-----------------------------
-- Populate application tables
set search_path=public,myschema1;
-- inserts/updates/deletes in myTbl1, myTbl2 and myTbl2b (via trigger)
insert into myTbl1 select i, 'ABC', E'\\014'::bytea from generate_series (1,11) as i;
begin transaction;
  update myTbl1 set col13=E'\\034'::bytea where col11 <= 3;
  insert into myTbl2 values (1,'ABC',current_date);
commit;
delete from myTbl1 where col11 > 10;
insert into myTbl2 values (2,'DEF',NULL);
insert into myTbl2 values (3,'GHI',NULL);
update myTbl2 set col22 = NULL WHERE col23 IS NULL;
delete from myTbl2 where col21 = 3 and col22 is NULL;
select count(*) from mytbl1;
select count(*) from mytbl2;
select count(*) from mytbl2b;
select count(*) from "myTbl3";
select count(*) from myTbl4;

-- set a mark
select emaj.emaj_set_mark_group('myGroup1','Mark12');
select mark_id, mark_group, regexp_replace(mark_name,E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d','%','g'), mark_global_seq, mark_is_deleted, mark_comment, mark_last_seq_hole_id, mark_last_sequence_id, mark_log_rows_before_next from emaj.emaj_mark order by mark_id;
select sequ_id,sequ_schema, sequ_name, regexp_replace(sequ_mark,E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d','%','g'), sequ_last_val, sequ_is_called from emaj.emaj_sequence order by sequ_id;

-- inserts/updates/deletes in myTbl3 and myTbl4
insert into "myTbl3" (col33) select generate_series(1000,1039,4)/100;
insert into myTbl4 values (1,'FK...',1,1,'ABC');
update myTbl4 set col43 = NULL where col41 = 1;
select count(*) from "myTbl3";
select count(*) from myTbl4;

-- set a mark
select emaj.emaj_set_mark_group('myGroup1','Mark13');

select mark_id, mark_group, regexp_replace(mark_name,E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d','%','g'), mark_global_seq, mark_is_deleted, mark_comment, mark_last_seq_hole_id, mark_last_sequence_id, mark_log_rows_before_next from emaj.emaj_mark order by mark_id;
select sequ_id,sequ_schema, sequ_name, regexp_replace(sequ_mark,E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d','%','g'), sequ_last_val, sequ_is_called from emaj.emaj_sequence order by sequ_id;
select col11, col12, col13, emaj_verb, emaj_tuple, emaj_gid from emaj.myschema1_mytbl1_log order by emaj_gid, emaj_tuple desc;
select col21, col22, emaj_verb, emaj_tuple, emaj_gid from emaj.myschema1_mytbl2_log order by emaj_gid, emaj_tuple desc;
select col20, col21, emaj_verb, emaj_tuple, emaj_gid from emajb.myschema1_mytbl2b_log order by emaj_gid, emaj_tuple desc;
select col31, col33, emaj_verb, emaj_tuple, emaj_gid from "emajC"."myschema1_myTbl3_log" order by emaj_gid, emaj_tuple desc;
select col41, col42, col43, col44, col45, emaj_verb, emaj_tuple, emaj_gid from emaj.myschema1_myTbl4_log order by emaj_gid, emaj_tuple desc;

-- rollback #1
alter table mySchema1.myTbl2 disable trigger myTbl2trg;
select emaj.emaj_rollback_group('myGroup1','Mark12');
alter table mySchema1.myTbl2 enable trigger myTbl2trg;
-- check impact
select mark_id, mark_group, regexp_replace(mark_name,E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d','%','g'), mark_global_seq, mark_is_deleted, mark_comment, mark_last_seq_hole_id, mark_last_sequence_id, mark_log_rows_before_next from emaj.emaj_mark order by mark_id;
select sequ_id,sequ_schema, sequ_name, regexp_replace(sequ_mark,E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d','%','g'), sequ_last_val, sequ_is_called from emaj.emaj_sequence order by sequ_id;
select sqhl_id, sqhl_schema, sqhl_table, sqhl_hole_size from emaj.emaj_seq_hole order by sqhl_id;
select col31, col33, emaj_verb, emaj_tuple, emaj_gid from "emajC"."myschema1_myTbl3_log" order by emaj_gid, emaj_tuple desc;
select col41, col42, col43, col44, col45, emaj_verb, emaj_tuple, emaj_gid from emaj.myschema1_myTbl4_log order by emaj_gid, emaj_tuple desc;
select col31, col33 from myschema1."myTbl3" order by col31;
select col41, col42, col43, col44, col45 from myschema1.myTbl4 order by col41;

-- rollback #2 (and stop)
alter table mySchema1.myTbl2 disable trigger myTbl2trg;
select emaj.emaj_rollback_group('myGroup1','Mark11');
alter table mySchema1.myTbl2 enable trigger myTbl2trg;
select emaj.emaj_stop_group('myGroup1');
-- check impact
select mark_id, mark_group, regexp_replace(mark_name,E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d','%','g'), mark_global_seq, mark_is_deleted, mark_comment, mark_last_seq_hole_id, mark_last_sequence_id, mark_log_rows_before_next from emaj.emaj_mark order by mark_id;
select sequ_id,sequ_schema, sequ_name, regexp_replace(sequ_mark,E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d','%','g'), sequ_last_val, sequ_is_called from emaj.emaj_sequence order by sequ_id;
select sqhl_id, sqhl_schema, sqhl_table, sqhl_hole_size from emaj.emaj_seq_hole order by sqhl_id;
select col11, col12, col13, emaj_verb, emaj_tuple, emaj_gid from emaj.myschema1_myTbl1_log order by emaj_gid, emaj_tuple desc;
select col21, col22, emaj_verb, emaj_tuple, emaj_gid from emaj.myschema1_myTbl2_log order by emaj_gid, emaj_tuple desc;
select col20, col21, emaj_verb, emaj_tuple, emaj_gid from emajb.myschema1_myTbl2b_log order by emaj_gid, emaj_tuple desc;
select col11, col12, col13 from myschema1.myTbl1 order by col11, col12;
select col21, col22 from myschema1.myTbl2 order by col21;
select col20, col21 from myschema1.myTbl2b order by col20;

-- restart group
select emaj.emaj_start_group('myGroup1','Mark11');

-- check the logs are empty again
select count(*) from emaj.myschema1_mytbl1_log;
select count(*) from emaj.myschema1_mytbl2_log;
select count(*) from emajb.myschema1_mytbl2b_log;
select count(*) from "emajC"."myschema1_myTbl3_log";
select count(*) from emaj.myschema1_mytbl4_log;

-----------------------------
-- log phase #2 with 2 unlogged rollbacks
-----------------------------
-- Populate application tables
set search_path=public,myschema1;
-- inserts/updates/deletes in myTbl1, myTbl2 and myTbl2b (via trigger)
insert into myTbl1 select i, 'ABC', E'\\014'::bytea from generate_series (1,11) as i;
begin transaction;
  update myTbl1 set col13=E'\\034'::bytea where col11 <= 3;
  insert into myTbl2 values (1,'ABC',current_date);
commit;
delete from myTbl1 where col11 > 10;
insert into myTbl2 values (2,'DEF',NULL);
select count(*) from mytbl1;
select count(*) from mytbl2;
select count(*) from mytbl2b;

-- set a mark
select emaj.emaj_set_mark_group('myGroup1','Mark12');

-- inserts/updates/deletes in myTbl3 and myTbl4
insert into "myTbl3" (col33) select generate_series(1000,1039,4)/100;
insert into myTbl4 values (1,'FK...',1,1,'ABC');
select count(*) from "myTbl3";
select count(*) from myTbl4;

-- set a mark
select emaj.emaj_set_mark_group('myGroup1','Mark13');

select mark_id, mark_group, regexp_replace(mark_name,E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d','%','g'), mark_global_seq, mark_is_deleted, mark_comment, mark_last_seq_hole_id, mark_last_sequence_id, mark_log_rows_before_next from emaj.emaj_mark order by mark_id;
select sequ_id,sequ_schema, sequ_name, regexp_replace(sequ_mark,E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d','%','g'), sequ_last_val, sequ_is_called from emaj.emaj_sequence order by sequ_id;
select col11, col12, col13, emaj_verb, emaj_tuple, emaj_gid from emaj.myschema1_mytbl1_log order by emaj_gid, emaj_tuple desc;
select col21, col22, emaj_verb, emaj_tuple, emaj_gid from emaj.myschema1_mytbl2_log order by emaj_gid, emaj_tuple desc;
select col20, col21, emaj_verb, emaj_tuple, emaj_gid from emajb.myschema1_mytbl2b_log order by emaj_gid, emaj_tuple desc;
select col31, col33, emaj_verb, emaj_tuple, emaj_gid from "emajC"."myschema1_myTbl3_log" order by emaj_gid, emaj_tuple desc;
select col41, col42, col43, col44, col45, emaj_verb, emaj_tuple, emaj_gid from emaj.myschema1_myTbl4_log order by emaj_gid, emaj_tuple desc;

-- logged rollback #1
alter table mySchema1.myTbl2 disable trigger myTbl2trg;
select emaj.emaj_logged_rollback_group('myGroup1','Mark12');
alter table mySchema1.myTbl2 enable trigger myTbl2trg;
-- check impact
select mark_id, mark_group, regexp_replace(mark_name,E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d','%','g'), mark_global_seq, mark_is_deleted, mark_comment, mark_last_seq_hole_id, mark_last_sequence_id, mark_log_rows_before_next from emaj.emaj_mark order by mark_id;
select sequ_id,sequ_schema, sequ_name, regexp_replace(sequ_mark,E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d','%','g'), sequ_last_val, sequ_is_called from emaj.emaj_sequence order by sequ_id;
select sqhl_id, sqhl_schema, sqhl_table, sqhl_hole_size from emaj.emaj_seq_hole order by sqhl_id;
select col31, col33, emaj_verb, emaj_tuple, emaj_gid from "emajC"."myschema1_myTbl3_log" order by emaj_gid, emaj_tuple desc;
select col41, col42, col43, col44, col45, emaj_verb, emaj_tuple, emaj_gid from emaj.myschema1_myTbl4_log order by emaj_gid, emaj_tuple desc;
select col31, col33 from myschema1."myTbl3" order by col31;
select col41, col42, col43, col44, col45 from myschema1.myTbl4 order by col41;

-- logged rollback #2
alter table mySchema1.myTbl2 disable trigger myTbl2trg;
select emaj.emaj_logged_rollback_group('myGroup1','Mark11');
alter table mySchema1.myTbl2 enable trigger myTbl2trg;
-- check impact
select mark_id, mark_group, regexp_replace(mark_name,E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d','%','g'), mark_global_seq, mark_is_deleted, mark_comment, mark_last_seq_hole_id, mark_last_sequence_id, mark_log_rows_before_next from emaj.emaj_mark order by mark_id;
select sequ_id,sequ_schema, sequ_name, regexp_replace(sequ_mark,E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d','%','g'), sequ_last_val, sequ_is_called from emaj.emaj_sequence order by sequ_id;
select sqhl_id, sqhl_schema, sqhl_table, sqhl_hole_size from emaj.emaj_seq_hole order by sqhl_id;
select col11, col12, col13, emaj_verb, emaj_tuple, emaj_gid from emaj.myschema1_myTbl1_log order by emaj_gid, emaj_tuple desc;
select col21, col22, emaj_verb, emaj_tuple, emaj_gid from emaj.myschema1_myTbl2_log order by emaj_gid, emaj_tuple desc;
select col20, col21, emaj_verb, emaj_tuple, emaj_gid from emajb.myschema1_myTbl2b_log order by emaj_gid, emaj_tuple desc;
select col11, col12, col13 from myschema1.myTbl1 order by col11, col12;
select col21, col22 from myschema1.myTbl2 order by col21;
select col20, col21 from myschema1.myTbl2b order by col20;

-----------------------------
-- unlogged rollback of logged rollbacks #3
-----------------------------
alter table mySchema1.myTbl2 disable trigger myTbl2trg;
select emaj.emaj_rollback_group('myGroup1','Mark13');
alter table mySchema1.myTbl2 enable trigger myTbl2trg;
-- check impact
select mark_id, mark_group, regexp_replace(mark_name,E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d','%','g'), mark_global_seq, mark_is_deleted, mark_comment, mark_last_seq_hole_id, mark_last_sequence_id, mark_log_rows_before_next from emaj.emaj_mark order by mark_id;
select sequ_id,sequ_schema, sequ_name, regexp_replace(sequ_mark,E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d','%','g'), sequ_last_val, sequ_is_called from emaj.emaj_sequence order by sequ_id;
select sqhl_id, sqhl_schema, sqhl_table, sqhl_hole_size from emaj.emaj_seq_hole order by sqhl_id;
select col11, col12, col13, emaj_verb, emaj_tuple, emaj_gid from emaj.myschema1_myTbl1_log order by emaj_gid, emaj_tuple desc;
select col21, col22, emaj_verb, emaj_tuple, emaj_gid from emaj.myschema1_myTbl2_log order by emaj_gid, emaj_tuple desc;
select col20, col21, emaj_verb, emaj_tuple, emaj_gid from emajb.myschema1_myTbl2b_log order by emaj_gid, emaj_tuple desc;
select col11, col12, col13 from myschema1.myTbl1 order by col11, col12;
select col21, col22 from myschema1.myTbl2 order by col21;
select col20, col21 from myschema1.myTbl2b order by col20;

-----------------------------
-- test use of partitionned tables
-----------------------------
select emaj.emaj_start_group('myGroup4','myGroup4_start');
insert into myschema4.myTblM values ('2001-09-11',0,'abc'),('2011-09-11',10,'def'),('2021-09-11',20,'ghi');

select emaj.emaj_set_mark_group('myGroup4','mark1');
delete from myschema4.myTblM;

select emaj.emaj_logged_rollback_group('myGroup4','mark1');

select col1, col2, col3, emaj_verb, emaj_tuple, emaj_gid from emaj.myschema4_mytblm_log;
select col1, col2, col3, emaj_verb, emaj_tuple, emaj_gid from emaj.myschema4_mytblc1_log;
select col1, col2, col3, emaj_verb, emaj_tuple, emaj_gid from emaj.myschema4_mytblc2_log;

select emaj.emaj_rollback_group('myGroup4','myGroup4_start');

-----------------------------
-- test emaj_cleanup_rollback_state()
-----------------------------
-- rollback a transaction with an E-Maj rollback to generate an ABORTED rollback event
begin;
  select emaj.emaj_rollback_group('myGroup4','myGroup4_start');
rollback;
select emaj.emaj_cleanup_rollback_state();

-----------------------------
-- test emaj_rollback_activity()
-----------------------------
-- insert necessary rows into rollback tables in order to test various cases of emaj_rollback_activity() reports.
-- these tests ares performed inside transactions that are then rolled back.
begin;
-- 1 rollback operation in EXECUTING state, but no rollback steps have started yet
  insert into emaj.emaj_rlbk (rlbk_id, rlbk_groups, rlbk_mark, rlbk_mark_datetime, rlbk_is_logged, rlbk_nb_session, 
             rlbk_nb_table, rlbk_nb_sequence, rlbk_eff_nb_table, rlbk_status, rlbk_start_datetime)
    values (1232,array['group1232'],'mark1232','2000-01-01 01:00:00',true,1,
             5,4,3,'EXECUTING',now()-'2 minutes'::interval);
  insert into emaj.emaj_rlbk_plan (rlbp_rlbk_id, rlbp_step, rlbp_schema, rlbp_table, rlbp_fkey,
             rlbp_estimated_duration, rlbp_start_time, rlbp_duration)
    values (1232, 'RLBK_TABLE','schema','t1','','50 seconds'::interval,null,null),
           (1232, 'RLBK_TABLE','schema','t2','','30 seconds'::interval,null,null),
           (1232, 'RLBK_TABLE','schema','t3','','20 seconds'::interval,null,null);
  select rlbk_id, rlbk_status, rlbk_remaining, rlbk_completion_pct from emaj._rollback_activity();
-- the first RLBK_TABLE has started, but the elapse of the step is not yet > estimated duration 
  update emaj.emaj_rlbk_plan set rlbp_start_time = now() - '11 seconds'::interval
    where rlbp_rlbk_id = 1232 and rlbp_table = 't1';
  select rlbk_id, rlbk_status, rlbk_remaining, rlbk_completion_pct from emaj._rollback_activity();
  select 1.0 - ((20.0 + 30.0)+(50.0 - 11.0)) / (20.0 + 30.0 + 50.0); -- the completion % should be 11%
-- the first RLBK_TABLE is completed, and the step duration < the estimated duration 
  update emaj.emaj_rlbk_plan set rlbp_start_time = now() - '45 seconds'::interval,
                                 rlbp_duration = '45 seconds'::interval
    where rlbp_rlbk_id = 1232 and rlbp_table = 't1';
  select rlbk_id, rlbk_status, rlbk_remaining, rlbk_completion_pct from emaj._rollback_activity();
  select 1.0 - (20.0 + 30.0) / (20.0 + 30.0 + 45.0);  -- the completion % should be 47%
-- the second RLBK_TABLE has started, but the elapse of the step is not yet > estimated duration 
  update emaj.emaj_rlbk_plan set rlbp_start_time = now() - '28 seconds'::interval
    where rlbp_rlbk_id = 1232 and rlbp_table = 't2';
  select rlbk_id, rlbk_status, rlbk_remaining, rlbk_completion_pct from emaj._rollback_activity();
  select 1.0 - (20.0 + (30.0 - 28.0)) / (20.0 + 30.0 + 45.0);  -- the completion % should be 77%
-- the second RLBK_TABLE has started, but the elapse of the step is already > estimated duration 
  update emaj.emaj_rlbk_plan set rlbp_start_time = now() - '40 seconds'::interval
    where rlbp_rlbk_id = 1232 and rlbp_table = 't2';
  select rlbk_id, rlbk_status, rlbk_remaining, rlbk_completion_pct from emaj._rollback_activity();
  select 1.0 - (20.0) / (20.0 + 40.0 + 45.0);  -- the completion % should be 81%
-- the second RLBK_TABLE has started, but the elapse of the step is already > estimated duration 
  update emaj.emaj_rlbk_plan set rlbp_start_time = now() - '60 seconds'::interval
    where rlbp_rlbk_id = 1232 and rlbp_table = 't2';
  select rlbk_id, rlbk_status, rlbk_remaining, rlbk_completion_pct from emaj._rollback_activity();
  select 1.0 - (20.0) / (20.0 + 60.0 + 45.0);  -- the completion % should be 84%
-- the second RLBK_TABLE is completed, and the step duration > the estimated duration 
  update emaj.emaj_rlbk_plan set rlbp_start_time = now() - '65 seconds'::interval,
                                 rlbp_duration = '65 seconds'::interval
    where rlbp_rlbk_id = 1232 and rlbp_table = 't2';
  select rlbk_id, rlbk_status, rlbk_remaining, rlbk_completion_pct from emaj._rollback_activity();
  select 1.0 - (20.0) / (20.0 + 65.0 + 45.0);  -- the completion % should be 85%
-- the third RLBK_TABLE has started, and is almost completed 
  update emaj.emaj_rlbk_plan set rlbp_start_time = now() - '19 seconds'::interval
    where rlbp_rlbk_id = 1232 and rlbp_table = 't3';
  select rlbk_id, rlbk_status, rlbk_remaining, rlbk_completion_pct from emaj._rollback_activity();
  select 1.0 - ((20.0 - 19.0)) / (20.0 + 65.0 + 45.0);  -- the completion % should be 99%
rollback;
begin;
-- 1 rollback operation in LOCKING state and without step other than LOCK_TABLE
  insert into emaj.emaj_rlbk (rlbk_id, rlbk_groups, rlbk_mark, rlbk_mark_datetime, rlbk_is_logged, rlbk_nb_session, 
             rlbk_nb_table, rlbk_nb_sequence, rlbk_eff_nb_table, rlbk_status, rlbk_start_datetime)
    values (1233,array['group1233'],'mark1233','2000-01-01 01:00:00',true,1,
             5,4,3,'LOCKING',now()-'2 minutes'::interval);
  insert into emaj.emaj_rlbk_plan (rlbp_rlbk_id, rlbp_step, rlbp_schema, rlbp_table, rlbp_fkey,
             rlbp_estimated_duration, rlbp_start_time, rlbp_duration)
    values (1233, 'LOCK_TABLE','schema','t1','',null,null,null),
           (1233, 'LOCK_TABLE','schema','t2','',null,null,null),
           (1233, 'LOCK_TABLE','schema','t3','',null,null,null);
  select rlbk_id, rlbk_status, rlbk_elapse, rlbk_remaining, rlbk_completion_pct from emaj._rollback_activity();
-- the rollback operation in LOCKING state now has RLBK_TABLE steps
  insert into emaj.emaj_rlbk_plan (rlbp_rlbk_id, rlbp_step, rlbp_schema, rlbp_table, rlbp_fkey,
             rlbp_estimated_duration, rlbp_start_time, rlbp_duration)
    values (1233, 'RLBK_TABLE','schema','t1','','0:20:00'::interval,null,null),
           (1233, 'RLBK_TABLE','schema','t2','','0:02:00'::interval,null,null),
           (1233, 'RLBK_TABLE','schema','t3','','0:00:20'::interval,null,null);
  select rlbk_id, rlbk_status, rlbk_elapse, rlbk_remaining, rlbk_completion_pct from emaj._rollback_activity();
-- +1 rollback operation in PLANNING state
  insert into emaj.emaj_rlbk (rlbk_id, rlbk_groups, rlbk_mark, rlbk_mark_datetime, rlbk_is_logged, rlbk_nb_session, 
             rlbk_nb_table, rlbk_nb_sequence, rlbk_eff_nb_table, rlbk_status, rlbk_start_datetime)
    values (1234,array['group1234'],'mark1234','2000-01-01 01:00:00',true,1,
             5,4,3,'PLANNING',now()-'1 minute'::interval);
  select rlbk_id, rlbk_groups, rlbk_mark, rlbk_mark_datetime, rlbk_is_logged, rlbk_nb_session, rlbk_nb_table,
         rlbk_nb_sequence, rlbk_eff_nb_table, rlbk_status, rlbk_elapse, rlbk_remaining, rlbk_completion_pct 
    from emaj._rollback_activity();
rollback;
-----------------------------
-- test end: check rollback tables, reset history and force sequences id
-----------------------------
select rlbk_id, rlbk_groups, rlbk_mark, rlbk_is_logged, rlbk_nb_session, rlbk_nb_table, rlbk_nb_sequence, 
       rlbk_eff_nb_table, rlbk_status, rlbk_begin_hist_id, 
       case when rlbk_end_datetime is null then 'null' else '[ts]' end as "end_datetime"
  from emaj.emaj_rlbk order by rlbk_id;
select rlbs_rlbk_id, rlbs_session, 
       case when rlbs_end_datetime is null then 'null' else '[ts]' end as "end_datetime"
  from emaj.emaj_rlbk_session order by rlbs_rlbk_id, rlbs_session;
select rlbp_rlbk_id, rlbp_step, rlbp_schema, rlbp_table, rlbp_fkey, rlbp_batch_number, rlbp_session,
       rlbp_fkey_def, rlbp_estimated_quantity, rlbp_estimate_method, rlbp_quantity
  from emaj.emaj_rlbk_plan order by rlbp_rlbk_id, rlbp_step, rlbp_schema, rlbp_table, rlbp_fkey;
select rlbt_step, rlbt_schema, rlbt_table, rlbt_fkey, rlbt_rlbk_id, rlbt_quantity from emaj.emaj_rlbk_stat
  order by rlbt_rlbk_id, rlbt_step, rlbt_schema, rlbt_table, rlbt_fkey;

select hist_id, hist_function, hist_event, hist_object, regexp_replace(regexp_replace(hist_wording,E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d','%','g'),E'\\[.+\\]','(timestamp)','g'), hist_user from 
  (select * from emaj.emaj_hist order by hist_id) as t;
truncate emaj.emaj_hist;
alter sequence emaj.emaj_hist_hist_id_seq restart 5000;
alter sequence emaj.emaj_mark_mark_id_seq restart 500;
alter sequence emaj.emaj_sequence_sequ_id_seq restart 5000;
alter sequence emaj.emaj_seq_hole_sqhl_id_seq restart 500;

