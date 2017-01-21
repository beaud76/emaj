-- upgrade_while_logging.sql : Upgrade from E-Maj 1.3. to next_version while groups are in logging state.
--
-----------------------------
-- emaj update to next_version
-----------------------------
--\! cp /usr/local/pg912/share/postgresql/extension/emaj.control.0.12.0 /usr/local/pg912/share/postgresql/extension/emaj.control

-- check the extension is available
select * from pg_available_extension_versions where name = 'emaj';

-- process the extension upgrade
ALTER EXTENSION emaj UPDATE TO 'next_version';

-----------------------------
-- check installation
-----------------------------
-- check impact in catalog
select extname, extversion from pg_extension where extname = 'emaj';

-- check the emaj_param content
SELECT param_value_text FROM emaj.emaj_param WHERE param_key = 'emaj_version';

-----------------------------
-- Check the tables and sequences after upgrade
-----------------------------
-- emaj tables and sequences
select time_id, time_last_emaj_gid, time_event from emaj.emaj_time_stamp order by time_id;
select last_value, is_called from emaj.emaj_time_stamp_time_id_seq;

select group_name, group_is_logging, group_is_rlbk_protected, group_nb_table, group_nb_sequence, group_is_rollbackable, 
       group_creation_time_id, group_last_alter_time_id, group_comment
  from emaj.emaj_group order by group_name;

select mark_id, mark_group, regexp_replace(mark_name,E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d','%','g'), 
       mark_time_id, mark_is_deleted, mark_is_rlbk_protected, mark_comment, 
       mark_log_rows_before_next, mark_logged_rlbk_target_mark 
  from emaj.emaj_mark order by mark_id;
select last_value, is_called from emaj.emaj_mark_mark_id_seq;

select sequ_schema, sequ_name, sequ_time_id, sequ_last_val, sequ_start_val, sequ_increment, sequ_max_val, sequ_min_val, sequ_cache_val, sequ_is_cycled, sequ_is_called from emaj.emaj_sequence order by sequ_time_id, sequ_schema, sequ_name;

select * from emaj.emaj_seq_hole order by sqhl_schema, sqhl_table, sqhl_begin_time_id;

select rlbk_id, rlbk_groups, rlbk_mark, rlbk_time_id, rlbk_is_logged, rlbk_nb_session, rlbk_nb_table, rlbk_nb_sequence, rlbk_eff_nb_table, rlbk_status, rlbk_begin_hist_id, rlbk_is_dblink_used, rlbk_msg from emaj.emaj_rlbk order by rlbk_id;
select last_value, is_called from emaj.emaj_rlbk_rlbk_id_seq;

-- log tables
select col11, col12, col13, emaj_verb, emaj_tuple, emaj_gid from emaj.mySchema1_myTbl1_log order by emaj_gid, emaj_tuple desc;
select col21, col22, col23, emaj_verb, emaj_tuple, emaj_gid from emaj.mySchema1_myTbl2_log order by emaj_gid, emaj_tuple desc;
select col20, col21, emaj_verb, emaj_tuple, emaj_gid from emaj.mySchema1_myTbl2b_log order by emaj_gid, emaj_tuple desc;
select col31, col33, emaj_verb, emaj_tuple, emaj_gid from emaj."myschema1_myTbl3_log" order by emaj_gid, emaj_tuple desc;
select col41, col42, col43, col44, col45, emaj_verb, emaj_tuple, emaj_gid from emaj.mySchema1_myTbl4_log order by emaj_gid, emaj_tuple desc;
--
select col11, col12, col13, emaj_verb, emaj_tuple, emaj_gid from emaj.mySchema2_myTbl1_log order by emaj_gid, emaj_tuple desc;
select col21, col22, col23, emaj_verb, emaj_tuple, emaj_gid from emaj.mySchema2_myTbl2_log order by emaj_gid, emaj_tuple desc;
select col31, col33, emaj_verb, emaj_tuple, emaj_gid from emaj."myschema2_myTbl3_log" order by emaj_gid, emaj_tuple desc;
select col41, col42, col43, col44, col45, emaj_verb, emaj_tuple, emaj_gid from emaj.mySchema2_myTbl4_log order by emaj_gid, emaj_tuple desc;
