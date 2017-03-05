
/*==============================================================*/
/* Vue : V_ICL_SCF_TAG_LOCATION                                */
/*==============================================================*/
CREATE OR REPLACE FORCE VIEW V_ICL_SCF_TAG_LOCATION AS 
  SELECT (CASE WHEN (SYSDATE < FROM_DATE) THEN 0 WHEN (TO_DATE <= SYSDATE) THEN 0 ELSE 1 END) AS NOW,
    SCF_TAG_LOCATION.TAG_LOCATION_PK,
    SCF_TAG_LOCATION.LOCATION_PK,
    SCF_LOCATION.LOCATION_ID,
    SCF_LOCATION.SP_PK,
    SCF_TAG_LOCATION.TAG_PK,
    SCF_TAG.TAG_ID,
    SCF_TAG_LOCATION.FROM_DATE,
    SCF_TAG_LOCATION.TO_DATE,
    f_dthr_zulu2local(SCF_LOCATION.SP_PK, SCF_TAG_LOCATION.FROM_DATE) AS FROM_LOCAL_DATE,
    f_dthr_zulu2local(SCF_LOCATION.SP_PK, SCF_TAG_LOCATION.TO_DATE) AS TO_LOCAL_DATE,
    SCF_TAG_LOCATION.COMMENTS
   FROM SCF_TAG_LOCATION, SCF_LOCATION, SCF_TAG
  WHERE SCF_TAG_LOCATION.LOCATION_PK = SCF_LOCATION.LOCATION_PK
    AND SCF_TAG_LOCATION.TAG_PK = SCF_TAG.tag_pk 
/

/*==============================================================*/
CREATE OR REPLACE TRIGGER TAIUD_V_ICL_SCF_TAG_LOCATION instead OF INSERT OR DELETE OR UPDATE
   ON V_ICL_SCF_TAG_LOCATION REFERENCING NEW AS NEW OLD AS OLD FOR EACH ROW
DECLARE
   integrity_error  EXCEPTION;
   errno            INTEGER;
   errmsg           VARCHAR2(200);
   sTrace           VARCHAR2(200);
BEGIN
  
   IF DELETING THEN 
     DELETE SCF_TAG_LOCATION 
     WHERE tag_location_pk = :OLD.tag_location_pk ;
     sTrace := 'Tag_location_pk (PK= ' || :OLD.tag_location_pk  || ') - '
        || 'tag=' || :OLD.tag_id || ' (PK=' || :OLD.tag_pk ||') <-> '
        || 'loc=' || :OLD.location_id || ' (PK=' || :OLD.location_pk || ') : Deleting' ;
   END IF;
   IF INSERTING THEN 
      -- Verification : FROM_DATE > 01/01/2015
      IF :NEW.FROM_LOCAL_DATE < TO_DATE('01/01/2015','DD/MM/YYYY') THEN
        RAISE_APPLICATION_ERROR(-20012, 'From_date must be greater than the 01/01/2015 !');
      END IF;

      INSERT INTO SCF_TAG_LOCATION
        (
          location_pk, tag_pk, from_date, to_date, comments
        )
        VALUES
        (
          :NEW.location_pk, :NEW.tag_pk, 
          f_dthr_local2zulu(:NEW.sp_pk ,:NEW.from_local_date), 
          f_dthr_local2zulu(:NEW.sp_pk ,:NEW.to_local_date), 
          :NEW.comments
        );
      sTrace := 'Tag_location_pk - '
        || 'tag=' || :NEW.tag_id || ' (PK=' || :NEW.tag_pk ||') <-> '
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
