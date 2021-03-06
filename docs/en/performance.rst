Performance
===========

Updates recording overhead
--------------------------

Recording updates in E-Maj log tables has necessarily an impact on the duration of these updates. The global impact of this log on a given processing depends on numerous factors. Among them:

* the part that the update activity represents on the global processing,
* the intrinsic performance characteristics of the storage subsystem that supports log tables.

However, the E-Maj updates recording overhead is generally limited to a few per-cents. But this overhead must be compared to the duration of potential intermediate saves avoided with E-Maj. 

E-Maj rollback duration
-----------------------

The duration of an E-Maj rollback depends on several factors, like:

* the number of updates to cancel,
* the intrinsic characteristics of the server and its storage material and the load generated by other activities hosted on the server,
* triggers or foreign keys on tables processed by the rollback operation,
* contentions on tables at lock set time.

To get an order of magnitude of an E-Maj rollback duration, it is possible to use the :ref:`emaj_estimate_rollback_group() <emaj_estimate_rollback_group>` and :doc:`emaj_estimate_rollback_groups() <multiGroupsFunctions>` functions.

Optimizing E-Maj operations
---------------------------

Here are some advice to optimize E-Maj operations.

Use tablespaces
^^^^^^^^^^^^^^^

Creating tables into tablespaces located in dedicated disks or file systems is a way to more efficiently spread the access to these tables. To minimize the disturbance of application tables access by log tables access, the E-Maj administrator has two ways to use tablespaces for log tables and indexes location.

By setting a specific default tablespace for the session before the tables groups creation, log tables and indexes are created by default into this tablespace, without any additional action.

But through parameters set when calling the :ref:`emaj_assign_table(), emaj_assign_tables()<assign_table_sequence>` and :ref:`emaj_modify_table()<modify_table>` functions, it is also possible to specify a tablespace to use for any log table or log index

Declare foreign keys as *DEFERRABLE* 
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Foreign keys can be explicitly declared as *DEFERRABLE* at creation time. If a foreign key is declared *DEFERRABLE* and no *ON DELETE* or *ON UPDATE* clause is used, this foreign key is not dropped at the beginning and recreated at the end of an E-Maj rollback operation. The foreign key checks of updated rows are just deferred to the end of the rollback function execution, once all log tables are processed. This generally greatly speeds up the rollback operation.

Modify memory parameters
^^^^^^^^^^^^^^^^^^^^^^^^

Increasing the value of the *work_mem* parameter when performing an E-Maj rollback may bring some performance gains.

If foreign keys have to be recreated by an E-Maj rollback operation, increasing the value of the *maintenance_work_mem* parameter may also help.

If the E-Maj rollback functions are directly called in SQL, these parameters can be previously set at session level by statements like::

   SET work_mem = <value>;
   SET maintenance_work_mem = <value>;

If the E-Maj rollback operations are executed by a web client, it is also possible to set these parameters at function level, as superuser::

   ALTER FUNCTION emaj._rlbk_tbl(emaj.emaj_relation, BIGINT, BIGINT, INT, BOOLEAN) SET work_mem = <value>;
   ALTER FUNCTION emaj._rlbk_session_exec(INT, INT) SET maintenance_work_mem = <value>;
