/*==============================================================*/
/* Vue : V_ICL_SCF_LOCATION_LINE                                */
/*==============================================================*/
CREATE OR REPLACE FORCE VIEW V_ICL_SCF_LOCATION_LINE AS 
  SELECT (CASE WHEN (SYSDATE < FROM_DATE) THEN 0 WHEN (TO_DATE <= SYSDATE) THEN 0 ELSE 1 END) AS NOW,
    SCF_LOCATION_LINE.LOCATION_LINE_PK,
    SCF_LOCATION_LINE.LOCATION_PK,
    SCF_LOCATION.LOCATION_ID,
    SCF_LOCATION.SP_PK,
    SCF_LOCATION_LINE.LINE_PK,
    SCF_LINE.LINE_ID,
    SCF_LOCATION_LINE.FROM_DATE,
    SCF_LOCATION_LINE.TO_DATE,
    f_dthr_zulu2local(SCF_LOCATION.SP_PK, SCF_LOCATION_LINE.FROM_DATE) AS FROM_LOCAL_DATE,
    f_dthr_zulu2local(SCF_LOCATION.SP_PK, SCF_LOCATION_LINE.TO_DATE) AS TO_LOCAL_DATE,
    SCF_LOCATION_LINE.COMMENTS
   FROM SCF_LOCATION_LINE, SCF_LOCATION, SCF_LINE
  WHERE SCF_LOCATION_LINE.LOCATION_PK = SCF_LOCATION.LOCATION_PK
/

/*==============================================================*/
CREATE OR REPLACE TRIGGER TAIUD_V_ICL_SCF_LOCATION_LINE instead OF INSERT OR DELETE OR UPDATE
   ON V_ICL_SCF_LOCATION_LINE REFERENCING NEW AS NEW OLD AS OLD FOR EACH ROW
DECLARE
   integrity_error  EXCEPTION;
   errno            INTEGER;
   errmsg           VARCHAR2(200);
   sTrace           VARCHAR2(200);
BEGIN
  
   IF DELETING THEN 
     DELETE SCF_LOCATION_LINE 
      WHERE location_line_pk = :OLD.location_line_pk ;
     sTrace := 'Location_line_pk - ' || :OLD.location_line_pk || ') - '
        || 'line=' || :OLD.line_id || ' (PK=' || :OLD.line_pk ||') <-> '
        || 'loc=' || :OLD.location_id || ' (PK=' || :OLD.location_pk || ') : Deleting' ;
   END IF;
   IF INSERTING THEN 
      -- Verification : FROM_DATE > 01/01/2015
      IF :NEW.FROM_LOCAL_DATE < TO_DATE('01/01/2015','DD/MM/YYYY') THEN
        RAISE_APPLICATION_ERROR(-20012, 'From_date must be greater than the 01/01/2015 !');
      END IF;

      INSERT INTO SCF_LOCATION_LINE
        (
          location_pk, line_pk, from_date, to_date, comments
        )
        VALUES
        (
          :NEW.location_pk, :NEW.line_pk, 
          f_dthr_local2zulu(:NEW.sp_pk ,:NEW.from_local_date), 
          f_dthr_local2zulu(:NEW.sp_pk ,:NEW.to_local_date), 
          :NEW.comments
        );
      sTrace := 'Location - ' || :NEW.location_pk || ' - line:' || :NEW.line_pk || ') : Inserting';
      sTrace := 'Location_line_pk - '
        || 'line=' || :NEW.line_id || ' (PK=' || :NEW.line_pk ||') <-> '
        || 'loc=' || :NEW.location_id || ' (PK=' || :NEW.location_pk || ') : Inserting';
    END IF;
   
   PKG_LOG.LogEvent( PKG_CST.LOG_TRT_ICL_CONF,   -- p_nIdTraitement
                     0,                          -- p_nDureeTraitement
                     0,                          -- p_nStatusExecution
                     0,                          -- p_ComplementStatus
                     sTrace,                     -- p_ComplementOracle
                     SYSDATE );

--  Traitement d'erreurs
EXCEPTION
    WHEN integrity_error THEN
       raise_application_error(errno, errmsg);
END;
/
