!> @file
!> @brief otlft() computes lifted index.
!>
!> This routine computes lifts a parcel specified by the
!> passed pressure, temperature, and specific humidity to
!> 500mb and then computes a lifted index.  This lifted
!> lifted index is the difference between the lifted
!> parcel's temperature at 500mb and the ambient 500mb
!> temperature.
!>
!> @param[in] PBND Parcel pressure.
!> @param[in] TBND Parcel temperature.
!> @param[in] QBND Parcel specific humidity.
!> @param[out] SLINDX Lifted index.
!>
!> ### Program History Log
!> Date | Programmer | Comments
!> -----|------------|---------
!> 1993-03-10 | Russ Treadon  | Initial. Modified OTLIFT2 to lift parcels specified by passed P, T, and Q.
!> 1998-06-15 | T Black       | Conversion from 1-D to 2-D
!> 2000-01-04 | Jim Tuccillo  | MPI Version
!> 2002-06-17 | Mike Baldwin  | WRF Version
!> 2011-04-12 | Geoff Manikin | Use virtual temperature
!> 2020-11-10 | Jesse Meng    | Use UPP_PHYSICS Module
!>
!> @author Russ Treadon W/NP2 @date 1993-03-10
      SUBROUTINE OTLFT(PBND,TBND,QBND,SLINDX)

!     
!     
      use vrbls2d,    only: T500
      use lookup_mod, only: THL, RDTH, JTB, QS0, SQS, RDQ, ITB, PTBL, &
                            PL, RDP, THE0, STHE, RDTHE, TTBL
      use ctlblk_mod, only: JSTA, JEND, IM, spval
      use params_mod, only: D00, H10E5, CAPA, ELOCP, EPS, ONEPS
      use upp_physics, only: FPVSNEW
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
       implicit none
!
!     SET LOCAL PARAMETERS.
       real,PARAMETER :: D8202=.820231E0 , H5E4=5.E4 , P500=50000.

!     
!     DECLARE VARIABLES.
      real,dimension(IM,jsta:jend),intent(in)  :: PBND,TBND,QBND
      real,dimension(IM,jsta:jend),intent(out) :: SLINDX
      REAL :: TVP, ESATP, QSATP
      REAL :: BQS00, SQS00, BQS10, SQS10, P00, P10, P01, P11, BQ, SQ, TQ
      REAL :: BTHE00, STHE00, BTHE10, STHE10, BTH, STH, TTH
      REAL :: T00, T10, T01, T11, TBT, QBT, APEBT, TTHBT, PPQ, PP
      REAL :: TQQ, QQ, TPSP, APESP, TTHES, TP, PARTMP
!     
      INTEGER :: I, J, ITTBK, IQ, IT, IPTBK, ITH, IP
      INTEGER :: ITTB, IQTB, IPTB, ITHTB
!     
!********************************************************************
!     START OTLFT HERE.
!     
!     ZERO LIFTED INDEX ARRAY.
!
!$omp parallel do private(i,j)
      DO J=JSTA,JEND
        DO I=1,IM
          SLINDX(I,J) = D00
        ENDDO
      ENDDO
!
!--------------FIND EXNER IN BOUNDARY LAYER-----------------------------
!
      DO J=JSTA,JEND
        DO I=1,IM
          TBT = TBND(I,J) 
          QBT = QBND(I,J)
!
          if( TBT < spval ) then

          APEBT = (H10E5/PBND(I,J))**CAPA
!
!--------------SCALING POTENTIAL TEMPERATURE & TABLE INDEX--------------
!
          TTHBT = TBT*APEBT
          TTH=(TTHBT-THL)*RDTH
          TQQ = TTH-AINT(TTH)
          ITTB = INT(TTH)+1
!
!--------------KEEPING INDICES WITHIN THE TABLE-------------------------
!
          IF(ITTB < 1)THEN
            ITTB = 1
            TQQ = D00
          ENDIF
          IF(ITTB >= JTB)THEN
            ITTB = JTB-1
            TQQ = D00
          ENDIF
!
!--------------BASE AND SCALING FACTOR FOR SPEC. HUMIDITY---------------
!
          ITTBK = ITTB
          BQS00=QS0(ITTBK)
          SQS00=SQS(ITTBK)
          BQS10=QS0(ITTBK+1)
          SQS10=SQS(ITTBK+1)
!
!--------------SCALING SPEC. HUMIDITY & TABLE INDEX---------------------
!
          BQ=(BQS10-BQS00)*TQQ+BQS00
          SQ=(SQS10-SQS00)*TQQ+SQS00
          TQ=(QBT-BQ)/SQ*RDQ
          PPQ = TQ-AINT(TQ)
          IQTB = INT(TQ)+1
!
!--------------KEEPING INDICES WITHIN THE TABLE-------------------------
!
          IF(IQTB < 1)THEN
            IQTB = 1
            PPQ = D00
          ENDIF
          IF(IQTB >= ITB)THEN
            IQTB = ITB-1
            PPQ = D00
          ENDIF
!
!--------------SATURATION PRESSURE AT FOUR SURROUNDING TABLE PTS.-------
!
          IQ=IQTB
          IT=ITTB
          P00=PTBL(IQ,IT)
          P10=PTBL(IQ+1,IT)
          P01=PTBL(IQ,IT+1)
          P11=PTBL(IQ+1,IT+1)
!
!--------------SATURATION POINT VARIABLES AT THE BOTTOM-----------------
!
          TPSP = P00+(P10-P00)*PPQ+(P01-P00)*TQQ     &
               +(P00-P10-P01+P11)*PPQ*TQQ
          IF(TPSP <= D00) TPSP = H10E5
          APESP = (H10E5/TPSP)**CAPA
          TTHES = TTHBT*EXP(ELOCP*QBT*APESP/TTHBT)
!
!-----------------------------------------------------------------------
!
!
!--------------SCALING PRESSURE & TT TABLE INDEX------------------------
!
          TP = (H5E4-PL)*RDP
          QQ = TP-AINT(TP)
          IPTB = INT(TP)+1
!
!--------------KEEPING INDICES WITHIN THE TABLE-------------------------
!
          IF(IPTB < 1)THEN
            IPTB = 1
            QQ = D00
          ENDIF
          IF(IPTB >= ITB)THEN
            IPTB = ITB-1
            QQ = D00
          ENDIF
!
!--------------BASE AND SCALING FACTOR FOR THE--------------------------
!
          IPTBK=IPTB
          BTHE00=THE0(IPTBK)
          STHE00=STHE(IPTBK)
          BTHE10=THE0(IPTBK+1)
          STHE10=STHE(IPTBK+1)
!
!--------------SCALING THE & TT TABLE INDEX-----------------------------
!
          BTH=(BTHE10-BTHE00)*QQ+BTHE00
          STH=(STHE10-STHE00)*QQ+STHE00
          TTH=(TTHES-BTH)/STH*RDTHE
          PP = TTH-AINT(TTH)
          ITHTB = INT(TTH)+1
!
!--------------KEEPING INDICES WITHIN THE TABLE-------------------------
!
          IF(ITHTB < 1)THEN
            ITHTB = 1
            PP = D00
          ENDIF
          IF(ITHTB >= JTB)THEN
            ITHTB = JTB-1
            PP = D00
          ENDIF
!
!--------------TEMPERATURE AT FOUR SURROUNDING TT TABLE PTS.------------
!
          ITH=ITHTB
          IP=IPTB
          T00=TTBL(ITH,IP)
          T10=TTBL(ITH+1,IP)
          T01=TTBL(ITH,IP+1)
          T11=TTBL(ITH+1,IP+1)
!
!--------------PARCEL TEMPERATURE AT 500MB----------------------------
!
          IF(TPSP >= H5E4)THEN
            PARTMP=(T00+(T10-T00)*PP+(T01-T00)*QQ     &
                  +(T00-T10-T01+T11)*PP*QQ)
          ELSE
            PARTMP=TBT*APEBT*D8202
          ENDIF
!
!--------------LIFTED INDEX---------------------------------------------
!
! GSM  THE PARCEL TEMPERATURE AT 500 MB HAS BEEN COMPUTED, AND WE
!       FIND THE MIXING RATIO AT THAT LEVEL WHICH WILL BE THE SATURATION
!       VALUE SINCE WE'RE FOLLOWING A MOIST ADIABAT.    NOTE THAT THE
!       AMBIENT 500 MB SHOULD PROBABLY BE VIRTUALIZED, BUT THE IMPACT
!       OF MOISTURE AT THAT LEVEL IS QUITE SMALL
           ESATP=FPVSNEW(PARTMP)
           QSATP=EPS*ESATP/(P500-ESATP*ONEPS)
           TVP=PARTMP*(1+0.608*QSATP)
           SLINDX(I,J)=T500(I,J)-TVP

           else
             SLINDX(I,J)=spval
           endif
         END DO
       END DO
!     
!     END OF ROUTINE.
      RETURN
      END
