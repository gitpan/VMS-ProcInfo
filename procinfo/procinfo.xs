/* VMS::ProcInfo - Get info for a VMS process
 *
 * Version: 1.01
 * Author:  Dan Sugalski <sugalsd@lbcc.cc.or.us>
 * Revised: 30-July-1997
 *
 *
 * Revision History:
 *
 * 0.1  30-July-1997 Dan Sugalski <sugalsd@lbcc.cc.or.us>
 *      Snagged base code from VMS::Priv.XS
 *
 */

#ifdef __cplusplus
extern "C" {
#endif
#include <starlet.h>
#include <descrip.h>
#include <prvdef.h>
#include <jpidef.h>
#include <uaidef.h>
#include <ssdef.h>
#include <stsdef.h>
#include <statedef.h>
#include <prcdef.h>
#include <pcbdef.h>
  
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

typedef struct {short   buflen,          /* Length of output buffer */
                        itmcode;         /* Item code */
                void    *buffer;         /* Buffer address */
                void    *retlen;         /* Return length address */
                } ITMLST;  /* Layout of item-list elements */

typedef struct {char  *ItemName;         /* Name of the item we're getting */
                unsigned short *ReturnLength; /* Pointer to the return */
                                              /* buffer length */
                void  *ReturnBuffer;     /* generic pointer to the returned */
                                         /* data */
                int   ReturnType;        /* The type of data in the return */
                                         /* buffer */
                int   ItemListEntry;     /* Index of the entry in the item */
                                         /* list we passed to GETJPI */
              } FetchedItem; /* Use this keep track of the items in the */
                             /* 'grab everything' GETJPI call */ 
                
/* Macro to fill in an item list entry */
#define init_itemlist(ile, length, code, bufaddr, retlen_addr) \
{ \
    (ile)->buflen = (length); \
    (ile)->itmcode = (code); \
    (ile)->buffer = (bufaddr); \
    (ile)->retlen = (retlen_addr) ;}

#define bit_test(HVPointer, BitToCheck, HVEntryName, EncodedMask) \
{ \
    if ((EncodedMask) && (BitToCheck)) \
    hv_store((HVPointer), (HVEntryName), strlen((HVEntryName)), &sv_yes, 0); \
    else \
    hv_store((HVPointer), (HVEntryName), strlen((HVEntryName)), &sv_no, 0);}   

#define IS_STRING 1
#define IS_LONGWORD 2
#define IS_QUADWORD 3
#define IS_WORD 4
#define IS_BYTE 5
#define IS_VMSDATE 6
#define IS_BITMAP 7   /* Each bit in the return value indicates something */
#define IS_ENUM 8     /* Each returned value has a name, and we ought to */
                      /* return the name instead of the value */

struct ProcInfoID {
  char *ProcInfoName; /* Pointer to the item name */
  int  JPIValue;      /* Value to use in the getjpi item list */
  int  BufferLen;     /* Length the return va buf needs to be. (no nul */
                      /* terminators, so must be careful with the return */
                      /* values. */
  int  ReturnType;    /* Type of data the item returns */
};

struct ProcInfoID ProcInfoList[] =
{
  {"ACCOUNT", JPI$_ACCOUNT, 8, IS_STRING},
  {"APTCNT", JPI$_APTCNT, 4, IS_LONGWORD},
  {"ASTACT", JPI$_ASTACT, 4, IS_LONGWORD},
  {"ASTCNT", JPI$_ASTCNT, 4, IS_LONGWORD},
  {"ASTEN", JPI$_ASTEN, 4, IS_LONGWORD},
  {"ASTLM", JPI$_ASTLM, 4, IS_LONGWORD},
  {"AUTHPRI", JPI$_AUTHPRI, 4, IS_LONGWORD},
  {"BIOCNT", JPI$_BIOCNT, 4, IS_LONGWORD},
  {"BIOLM", JPI$_BIOLM, 4, IS_LONGWORD},
  {"BUFIO", JPI$_BUFIO, 4, IS_LONGWORD},
  {"BYTCNT", JPI$_BYTCNT, 4, IS_LONGWORD},
  {"BYTLM", JPI$_BYTLM, 4, IS_LONGWORD},
  {"CLINAME", JPI$_CLINAME, 39, IS_STRING},
  {"CPUID", JPI$_CPU_ID, 4, IS_LONGWORD},
  {"CPULIM", JPI$_CPULIM, 4, IS_LONGWORD},
  {"CPUTIM", JPI$_CPUTIM, 4, IS_LONGWORD},
  {"CREPRC_FLAGS", JPI$_CREPRC_FLAGS, 4, IS_BITMAP},
  {"CURRENT_AFFINITY_MASK", JPI$_CURRENT_AFFINITY_MASK, 4, IS_LONGWORD},
#ifdef  JPI$_CURRENT_USERCAP_MASK
  {"CURRENT_USERCAP_MASK", JPI$_CURRENT_USERCAP_MASK, 4, IS_BITMAP},
#endif
#ifdef JPI$_DFMBC
  {"DFMBC", JPI$_DFMBC, 4, IS_LONGWORD},
#endif
#ifdef JPI$_DFPFC
  {"DFPFC", JPI$_DFPFC, 4, IS_LONGWORD},
#endif
  {"DIOCNT", JPI$_DIOCNT, 4, IS_LONGWORD},
  {"DIOLM", JPI$_DIOLM, 4, IS_LONGWORD},
  {"DIRIO", JPI$_DIRIO, 4, IS_LONGWORD},
  {"EFCS", JPI$_EFCS, 4, IS_LONGWORD},
  {"EFCU", JPI$_EFCU, 4, IS_LONGWORD},
  {"EFWM", JPI$_EFWM, 4, IS_LONGWORD},
  {"ENQCNT", JPI$_ENQCNT, 4, IS_LONGWORD},
  {"ENQLM", JPI$_ENQLM, 4, IS_LONGWORD},
  {"FAST_VP_SWITCH", JPI$_FAST_VP_SWITCH, 4, IS_LONGWORD},
  {"FILCNT", JPI$_FILCNT, 4, IS_LONGWORD},
  {"FILLM", JPI$_FILLM, 4, IS_LONGWORD},
#ifdef __VAX
  {"FREP0VA", JPI$_FREP0VA, 4, IS_LONGWORD},
#else
  {"FREP0VA", JPI$_FREP0VA, 8, IS_QUADWORD},
#endif
#ifdef __VAX
  {"FREP1VA", JPI$_FREP1VA, 4, IS_LONGWORD},
#else
  {"FREP1VA", JPI$_FREP1VA, 8, IS_QUADWORD},
#endif
#ifdef __VAX
  {"FREPTECNT", JPI$_FREPTECNT, 4, IS_LONGWORD},
#else
  {"FREPTECNT", JPI$_FREPTECNT, 8, IS_QUADWORD},
#endif
  {"GPGCNT", JPI$_GPGCNT, 4, IS_LONGWORD},
  {"GRP", JPI$_GRP, 4, IS_LONGWORD},
  {"IMAGECOUNT", JPI$_IMAGECOUNT, 4, IS_LONGWORD},
  {"IMAGNAME", JPI$_IMAGNAME, 255, IS_STRING},
  {"JOBPRCCNT", JPI$_JOBPRCCNT, 4, IS_LONGWORD},
  {"JOBTYPE", JPI$_JOBTYPE, 4, IS_ENUM},
  {"LAST_LOGIN_I", JPI$_LAST_LOGIN_I, 8, IS_VMSDATE},
  {"LAST_LOGIN_N", JPI$_LAST_LOGIN_N, 8, IS_VMSDATE},
  {"LOGIN_FAILURES", JPI$_LOGIN_FAILURES, 4, IS_LONGWORD},
  {"LOGIN_FLAGS", JPI$_LOGIN_FLAGS, 4, IS_BITMAP},
  {"LOGINTIM", JPI$_LOGINTIM, 8, IS_VMSDATE},
  {"MASTER_PID", JPI$_MASTER_PID, 4, IS_LONGWORD},
  {"MAXDETACH", JPI$_MAXDETACH, 4, IS_LONGWORD},
  {"MAXJOBS", JPI$_MAXJOBS, 4, IS_LONGWORD},
  {"MEM", JPI$_MEM, 4, IS_LONGWORD},
  {"MODE", JPI$_MODE, 4, IS_ENUM},
  {"MSGMASK", JPI$_MSGMASK, 4, IS_BITMAP},
  {"NODENAME", JPI$_NODENAME, 255, IS_STRING},
  {"NODE_CSID", JPI$_NODE_CSID, 4, IS_LONGWORD},
  {"NODE_VERSION", JPI$_NODE_VERSION, 255, IS_STRING},
  {"OWNER", JPI$_OWNER, 4, IS_LONGWORD},
  {"PAGEFLTS", JPI$_PAGEFLTS, 4, IS_LONGWORD},
  {"PAGFILCNT", JPI$_PAGFILCNT, 4, IS_LONGWORD},
  {"PAGFILLOC", JPI$_PAGFILLOC, 4, IS_LONGWORD},
  {"PERMANENT_AFFINITY_MASK", JPI$_PERMANENT_AFFINITY_MASK, 4, IS_LONGWORD},
  {"PERMANENT_USERCAP_MASK", JPI$_PERMANENT_USERCAP_MASK, 4, IS_BITMAP},
  {"PGFLQUOTA", JPI$_PGFLQUOTA, 4, IS_LONGWORD},
  {"PHDFLAGS", JPI$_PHDFLAGS, 4, IS_BITMAP},
  {"PID", JPI$_PID, 4, IS_LONGWORD},
#ifdef JPI$_P0_FIRST_FREE_VA_64
  {"P0_FIRST_FREE_VA_64", JPI$_P0_FIRST_FREE_VA_64, 4, IS_QUADWORD},
#endif
#ifdef JPI$_P1_FIRST_FREE_VA_64
  {"P1_FIRST_FREE_VA_64", JPI$_P1_FIRST_FREE_VA_64, 4, IS_QUADWORD},
#endif
#ifdef JPI$_P2_FIRST_FREE_VA_64
  {"P2_FIRST_FREE_VA_64", JPI$_P2_FIRST_FREE_VA_64, 4, IS_QUADWORD},
#endif
  {"PPGCNT", JPI$_PPGCNT, 4, IS_LONGWORD},
  {"PRCCNT", JPI$_PRCCNT, 4, IS_LONGWORD},
  {"PRCLM", JPI$_PRCLM, 4, IS_LONGWORD},
  {"PRCNAM", JPI$_PRCNAM, 15, IS_STRING},
  {"PRI", JPI$_PRI, 4, IS_LONGWORD},
  {"PRIB", JPI$_PRIB, 4, IS_LONGWORD},
  {"PROC_INDEX", JPI$_PROC_INDEX, 4, IS_LONGWORD},
  {"RIGHTS_SIZE", JPI$_RIGHTS_SIZE, 4, IS_LONGWORD},
  {"SCHED_POLICY", JPI$_SCHED_POLICY, 4, IS_ENUM},
  {"SHRFILLM", JPI$_SHRFILLM, 4, IS_LONGWORD},
  {"SITESPEC", JPI$_SITESPEC, 4, IS_LONGWORD},
  {"SLOW_VP_SWITCH", JPI$_SLOW_VP_SWITCH, 4, IS_LONGWORD},
  {"STATE", JPI$_STATE, 4, IS_ENUM},
  {"STS", JPI$_STS, 4, IS_BITMAP},
  {"STS2", JPI$_STS2, 4, IS_BITMAP},
  {"SWPFILLOC", JPI$_SWPFILLOC, 4, IS_LONGWORD},
  {"TABLENAME", JPI$_TABLENAME, 255, IS_STRING},
  {"TERMINAL", JPI$_TERMINAL, 8, IS_STRING},
  {"TMBU", JPI$_TMBU, 4, IS_LONGWORD},
  {"TQCNT", JPI$_TQCNT, 4, IS_LONGWORD},
  {"TQLM", JPI$_TQLM, 4, IS_LONGWORD},
  {"TT_ACCPORNAM", JPI$_TT_ACCPORNAM, 255, IS_STRING},
  {"TT_PHYDEVNAM", JPI$_TT_PHYDEVNAM, 255, IS_STRING},
  {"UAF_FLAGS", JPI$_UAF_FLAGS, 4, IS_BITMAP},
  {"UIC", JPI$_UIC, 4, IS_LONGWORD},
  {"USERNAME", JPI$_USERNAME, 12, IS_STRING},
  /* This should be a quadword on Alphas, but that bit's not done yet */
#ifdef __VAX
  {"VIRTPEAK", JPI$_VIRTPEAK, 4, IS_LONGWORD},
#else
  {"VIRTPEAK", JPI$_VIRTPEAK, 8, IS_QUADWORD},
#endif
  {"VOLUMES", JPI$_VOLUMES, 4, IS_LONGWORD},
  /* no VP_CONSUMER 'cause we don't do bytes yet */
  /*{"VP_CONSUMER", JPI$_VP_CONSUMER, 1, IS_BYTE} */
  {"VP_CPUTIM", JPI$_VP_CPUTIM, 4, IS_LONGWORD},
  {"WSAUTH", JPI$_WSAUTH, 4, IS_LONGWORD},
  {"WSAUTHEXT", JPI$_WSAUTHEXT, 4, IS_LONGWORD},
  {"WSEXTENT", JPI$_WSEXTENT, 4, IS_LONGWORD},
  {"WSPEAK", JPI$_WSPEAK, 4, IS_LONGWORD},
  {"WSQUOTA", JPI$_WSQUOTA, 4, IS_LONGWORD},
  {"WSSIZE", JPI$_WSSIZE, 4, IS_LONGWORD},
  {NULL, 0, 0, 0}
};

char *MonthNames[12] = {
  "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep",
  "Oct", "Nov", "Dec"} ;

/* Globals to track how many different pieces of info we can return, as */
/* well as how much space we'd need to grab to store it. */
static int ProcInfoCount = 0;
static int ProcInfoMallocSize = 0;

void
tote_up_info_count()
{
  for(ProcInfoCount = 0; ProcInfoList[ProcInfoCount].ProcInfoName;
      ProcInfoCount++) {
    /* While we're here, we might as well get a generous estimate of how */
    /* much space we'll need for all the buffers */
    ProcInfoMallocSize += ProcInfoList[ProcInfoCount].BufferLen;
    /* Add in a couple extra, just to be safe */
    ProcInfoMallocSize += 8;
  }
}    

/* This routine takes a JPI item list ID and the value that wants to be */
/* de-enumerated and returns a pointer to an SV with the de-enumerated name */
/* in it */
SV *
enum_name(long jpi_entry, long val_to_deenum)
{
  SV *WorkingSV = newSV(10);
  char *JobTypeNames[] = {"DETACHED", "NETWORK", "BATCH", "LOCAL",
                            "DIALUP", "REMOTE"};
  char *ModeNames[] = {"OTHER", "NETWORK", "BATCH", "INTERACTIVE"};
  switch (jpi_entry) {
  case JPI$_JOBTYPE:
    sv_setpv(WorkingSV, JobTypeNames[val_to_deenum]);
    break;
  case JPI$_MODE:
    sv_setpv(WorkingSV, ModeNames[val_to_deenum]);
    break;
#ifdef __ALPHA
  case JPI$_SCHED_POLICY:
    switch (val_to_deenum) {
    case JPI$K_DEFAULT_POLICY:
      sv_setpv(WorkingSV, "DEFAULT POLICY");
      break;
    case JPI$K_PSX_FIFO_POLICY:
      sv_setpv(WorkingSV, "PSX FIFO POLICY");
      break;
    case JPI$K_PSX_RR_POLICY:
      sv_setpv(WorkingSV, "PSX RR POLICY");
      break;
    default:
      sv_setpv(WorkingSV, "Unknown");
      break;
    }
    break;
#endif
  case JPI$_STATE:
    switch (val_to_deenum) {
    case SCH$C_CEF:
      sv_setpv(WorkingSV, "CEF");
      break;
    case SCH$C_COM:
      sv_setpv(WorkingSV, "COM");
      break;
    case SCH$C_COMO:
      sv_setpv(WorkingSV, "COMO");
      break;
    case SCH$C_CUR:
      sv_setpv(WorkingSV, "CUR");
      break;
    case SCH$C_COLPG:
      sv_setpv(WorkingSV, "COLPG");
      break;
    case SCH$C_FPG:
      sv_setpv(WorkingSV, "FPG");
      break;
    case SCH$C_HIB:
      sv_setpv(WorkingSV, "HIB");
      break;
    case SCH$C_HIBO:
      sv_setpv(WorkingSV, "HIBO");
      break;
    case SCH$C_LEF:
      sv_setpv(WorkingSV, "LEF");
      break;
    case SCH$C_LEFO:
      sv_setpv(WorkingSV, "LEFO");
      break;
    case SCH$C_MWAIT:
      sv_setpv(WorkingSV, "MWAIT");
      break;
    case SCH$C_PFW:
      sv_setpv(WorkingSV, "PFW");
      break;
    case SCH$C_SUSP:
      sv_setpv(WorkingSV, "SUSPO");
      break;
    case SCH$C_SUSPO:
      sv_setpv(WorkingSV, "SUSPO");
      break;
    default:
      sv_setpv(WorkingSV, "Unknown");
      break;
    }
    break;
  default:
    sv_setpv(WorkingSV, "Unknown");
    break;
  }

  return WorkingSV;
}

MODULE = VMS::ProcInfo		PACKAGE = VMS::ProcInfo		

void
proc_info_names()
   PPCODE:
   {
     int i;
     for (i=0; ProcInfoList[i].ProcInfoName; i++) {
       XPUSHs(sv_2mortal(newSVpv(ProcInfoList[i].ProcInfoName, 0)));
     }
   }

SV *
get_one_proc_info_item(pid, infoname)
     int pid;
     SV *infoname
   CODE:
{     
  int i;
  char *ReturnStringBuffer;            /* Return buffer pointer for strings */
  char ReturnByteBuffer;               /* Return buffer for bytes */
  unsigned short ReturnWordBuffer;     /* Return buffer for words */
  unsigned long ReturnLongWordBuffer;  /* Return buffer for longwords */
  unsigned short BufferLength;
  unsigned __int64 ReturnQuadWordBuffer;
  int status;
  unsigned short ReturnedTime[7];
  char AsciiTime[100];
  char QuadWordString[65];
  
  for (i = 0; ProcInfoList[i].ProcInfoName; i++) {
    if (strEQ(ProcInfoList[i].ProcInfoName, SvPV(infoname, na))) {
      break;
    }
  }

  /* Did we find a match? If not, complain and exit */
  if (ProcInfoList[i].ProcInfoName == NULL) {
    warn("Invalid proc info item");
    ST(0) = &sv_undef;
  } else {
    /* allocate our item list */
    ITMLST OneItem[2];

    /* Clear the buffer */
    Zero(&OneItem[0], 2, ITMLST);

    /* Fill in the itemlist depending on the return type */
    switch(ProcInfoList[i].ReturnType) {
    case IS_STRING:
    case IS_VMSDATE:
      /* Allocate the return data buffer and zero it. Can be oddly sized, so */
      /* we use the system malloc instead of New */
      ReturnStringBuffer = malloc(ProcInfoList[i].BufferLen);
      memset(ReturnStringBuffer, 0, ProcInfoList[i].BufferLen);

      /* Fill in the item list */
      init_itemlist(&OneItem[0], ProcInfoList[i].BufferLen,
                    ProcInfoList[i].JPIValue, ReturnStringBuffer,
                    &BufferLength);
      
      /* Done */
      break;
    case IS_QUADWORD:
      /* Fill in the item list */
      init_itemlist(&OneItem[0], ProcInfoList[i].BufferLen,
                    ProcInfoList[i].JPIValue, &ReturnQuadWordBuffer,
                    &BufferLength);
      break;
    case IS_ENUM:
    case IS_BITMAP:
    case IS_LONGWORD:
      /* Fill in the item list */
      init_itemlist(&OneItem[0], ProcInfoList[i].BufferLen,
                    ProcInfoList[i].JPIValue, &ReturnLongWordBuffer,
                    &BufferLength);
      break;
    default:
      warn("Unknown item return type");
      ST(0) = &sv_undef;
      return;
    }
    
    /* Make the call */
    status = sys$getjpiw(NULL, &pid, NULL, OneItem, 0, NULL, 0);

    /* Ok? */
    if (status == SS$_NORMAL) {
      /* Guess so. Grab the data and return it */
      switch(ProcInfoList[i].ReturnType) {
      case IS_STRING:
        ST(0) = sv_2mortal(newSVpv(ReturnStringBuffer, 0));
        /* Give back the buffer */
        free(ReturnStringBuffer);
        break;
      case IS_QUADWORD:
        sprintf(QuadWordString, "%llu", ReturnQuadWordBuffer);
        ST(0) = sv_2mortal(newSVpv(QuadWordString, 0));
        break;
      case IS_VMSDATE:
        sys$numtim(ReturnedTime, ReturnStringBuffer);
        sprintf(AsciiTime, "%02hi-%s-%hi %02hi:%02hi:%02hi.%hi",
                ReturnedTime[2], MonthNames[ReturnedTime[1] - 1],
                ReturnedTime[0], ReturnedTime[3], ReturnedTime[4],
                ReturnedTime[5], ReturnedTime[6]);
        ST(0) = sv_2mortal(newSVpv(AsciiTime, 0));
        free(ReturnStringBuffer);
        break;
      case IS_ENUM:
        ST(0) = enum_name(ProcInfoList[i].JPIValue, ReturnLongWordBuffer);
        break;
      case IS_BITMAP:
      case IS_LONGWORD:
        ST(0) =  sv_2mortal(newSViv(ReturnLongWordBuffer));
        break;
      default:
        ST(0) = &sv_undef;
        break;
      }

      
    } else {
      SETERRNO(EVMSERR, status);
      ST(0) = &sv_undef;
      /* free up the buffer if we were looking for a string */
      if (ProcInfoList[i].ReturnType == IS_STRING)
        free(ReturnStringBuffer);
    }
  }
}

void
get_all_proc_info_items(pid)
     int pid
   CODE:
{
     ITMLST *ListOItems;
     unsigned short *ReturnLengths;
     long *TempLongPointer;
     __int64 *TempQuadPointer;
     FetchedItem *OurDataList;
     int i, status;
     HV *AllPurposeHV;
     unsigned short ReturnedTime[7];
     char AsciiTime[100];
     char QuadWordString[65];
     
     /* If we've not gotten the count of items, go get it now */
     if (ProcInfoCount == 0) {
       tote_up_info_count();
     }
     
     /* We need room for our item list */
     ListOItems = malloc(sizeof(ITMLST) * (ProcInfoCount + 1));
     memset(ListOItems, 0, sizeof(ITMLST) * (ProcInfoCount + 1));
     OurDataList = malloc(sizeof(FetchedItem) * ProcInfoCount);
     
     /* We also need room for the buffer lengths */
     ReturnLengths = malloc(sizeof(short) * ProcInfoCount);

     /* Fill in the item list and the tracking list */
     for (i = 0; i < ProcInfoCount; i++) {
       /* Allocate the return data buffer and zero it. Can be oddly
          sized, so we use the system malloc instead of New */
       OurDataList[i].ReturnBuffer = malloc(ProcInfoList[i].BufferLen);
       memset(OurDataList[i].ReturnBuffer, 0, ProcInfoList[i].BufferLen);
         
       /* Note some important stuff (like what we're doing) in our local */
       /* tracking array */
       OurDataList[i].ItemName = ProcInfoList[i].ProcInfoName;
       OurDataList[i].ReturnLength = &ReturnLengths[i];
       OurDataList[i].ReturnType = ProcInfoList[i].ReturnType;
       OurDataList[i].ItemListEntry = i;
       
       /* Fill in the item list */
       init_itemlist(&ListOItems[i], ProcInfoList[i].BufferLen,
                     ProcInfoList[i].JPIValue, OurDataList[i].ReturnBuffer,
                     &ReturnLengths[i]);

     }

     /* Make the GETJPIW call */
     status = sys$getjpiw(NULL, &pid, NULL, ListOItems, 0, NULL, 0);
     /* Did it go OK? */
     if (status == SS$_NORMAL) {
       /* Looks like it */
       AllPurposeHV = newHV();
       for (i = 0; i < ProcInfoCount; i++) {
         switch(OurDataList[i].ReturnType) {
         case IS_STRING:
           hv_store(AllPurposeHV, OurDataList[i].ItemName,
                    strlen(OurDataList[i].ItemName),
                    newSVpv(OurDataList[i].ReturnBuffer,
                                       *OurDataList[i].ReturnLength), 0);
           break;
         case IS_VMSDATE:
           sys$numtim(ReturnedTime, OurDataList[i].ReturnBuffer);
           sprintf(AsciiTime, "%02hi-%s-%hi %02hi:%02hi:%02hi.%hi",
                   ReturnedTime[2], MonthNames[ReturnedTime[1] - 1],
                   ReturnedTime[0], ReturnedTime[3], ReturnedTime[4],
                   ReturnedTime[5], ReturnedTime[6]);
           hv_store(AllPurposeHV, OurDataList[i].ItemName,
                    strlen(OurDataList[i].ItemName),
                    newSVpv(AsciiTime, 0), 0);
           break;
         case IS_ENUM:
           TempLongPointer = OurDataList[i].ReturnBuffer;
           hv_store(AllPurposeHV, OurDataList[i].ItemName,
                    strlen(OurDataList[i].ItemName),
                    enum_name(ProcInfoList[i].JPIValue,
                              *TempLongPointer), 0);
           break;
         case IS_BITMAP:
         case IS_LONGWORD:
           TempLongPointer = OurDataList[i].ReturnBuffer;
           hv_store(AllPurposeHV, OurDataList[i].ItemName,
                    strlen(OurDataList[i].ItemName),
                    newSViv(*TempLongPointer),
                    0);
           break;
         case IS_QUADWORD:
           TempQuadPointer = OurDataList[i].ReturnBuffer;
           sprintf(QuadWordString, "%llu", *TempQuadPointer);
           hv_store(AllPurposeHV, OurDataList[i].ItemName,
                    strlen(OurDataList[i].ItemName),
                    newSVpv(QuadWordString, 0), 0);
           break;
             
         }
       }
       ST(0) = newRV_noinc((SV *) AllPurposeHV);
     } else {
       /* I think we failed */
       SETERRNO(EVMSERR, status);
       ST(0) = &sv_undef;
     }

     /* Free up our allocated memory */
     for(i = 0; i < ProcInfoCount; i++) {
       free(OurDataList[i].ReturnBuffer);
     }
     free(OurDataList);
     free(ReturnLengths);
     free(ListOItems);
   }

SV *
decode_proc_info_bitmap(InfoName, BitmapValue)
     char *InfoName
     int BitmapValue
   CODE:
{
  HV *AllPurposeHV;
  if (!strcmp(InfoName, "CREPRC_FLAGS")) {
    AllPurposeHV = newHV();
    bit_test(AllPurposeHV, PRC$M_BATCH, "BATCH", BitmapValue);
    bit_test(AllPurposeHV, PRC$M_DETACH, "DETACH", BitmapValue);
    bit_test(AllPurposeHV, PRC$M_DISAWS, "DISAWS", BitmapValue);
    bit_test(AllPurposeHV, PRC$M_HIBER, "HIBER", BitmapValue);
    bit_test(AllPurposeHV, PRC$M_IMGDMP, "IMGDMP", BitmapValue);
    bit_test(AllPurposeHV, PRC$M_INTER, "INTER", BitmapValue);
    bit_test(AllPurposeHV, PRC$M_NETWRK, "NETWRK", BitmapValue);
    bit_test(AllPurposeHV, PRC$M_NOACNT, "NOACNT", BitmapValue);
    bit_test(AllPurposeHV, PRC$M_NOPASSWORD, "NOPASSWORD", BitmapValue);
    bit_test(AllPurposeHV, PRC$M_LOGIN, "LOGIN", BitmapValue);
    bit_test(AllPurposeHV, PRC$M_PSWAPM, "PSWAPM", BitmapValue);
    bit_test(AllPurposeHV, PRC$M_SSFEXCU, "SSFEXCU", BitmapValue);
    bit_test(AllPurposeHV, PRC$M_SSRWAIT, "SSRWAIT", BitmapValue);
    bit_test(AllPurposeHV, PRC$M_SUBSYSTEM, "SUBSYSTEM", BitmapValue);
    bit_test(AllPurposeHV, PRC$M_TCB, "TCB", BitmapValue);
  } else {
  if (!strcmp(InfoName, "CURRENT_USERCAP_MASK")) {
    AllPurposeHV = newHV();
  } else {
  if (!strcmp(InfoName, "LOGIN_FLAGS")) {
    AllPurposeHV = newHV();
    bit_test(AllPurposeHV, JPI$M_NEW_MAIL_AT_LOGIN, "NEW_MAIL_AT_LOGIN", BitmapValue);
    bit_test(AllPurposeHV, JPI$M_PASSWORD_CHANGED, "PASSWORD_CHANGED", BitmapValue);
    bit_test(AllPurposeHV, JPI$M_PASSWORD_EXPIRED, "PASSWORD_EXPIRED", BitmapValue);
    bit_test(AllPurposeHV, JPI$M_PASSWORD_WARNING, "PASSWORD_WARNING", BitmapValue);
    bit_test(AllPurposeHV, JPI$M_PASSWORD2_CHANGED, "PASSWORD2_CHANGED", BitmapValue);
    bit_test(AllPurposeHV, JPI$M_PASSWORD2_WARNING, "PASSWORD2_WARNING", BitmapValue);
    bit_test(AllPurposeHV, JPI$M_PASSWORD2_EXPIRED, "PASSWORD2_EXPIRED", BitmapValue);
  } else {
  if (!strcmp(InfoName, "MSGMASK")) {
    AllPurposeHV = newHV();
  } else {
  if (!strcmp(InfoName, "PERMANENT_USERCAP_MASK")) {
    AllPurposeHV = newHV();
  } else {
  if (!strcmp(InfoName, "STS")) {
    AllPurposeHV = newHV();
    bit_test(AllPurposeHV, PCB$M_ASTPEN, "ASTPEN", BitmapValue);
    bit_test(AllPurposeHV, PCB$M_BATCH, "BATCH", BitmapValue);
    bit_test(AllPurposeHV, PCB$M_DELPEN, "DELPEN", BitmapValue);
    bit_test(AllPurposeHV, PCB$M_DISAWS, "DISAWS", BitmapValue);
    bit_test(AllPurposeHV, PCB$M_FORCPEN, "FORCPEN", BitmapValue);
    bit_test(AllPurposeHV, PCB$M_HARDAFF, "HARDAFF", BitmapValue);
    bit_test(AllPurposeHV, PCB$M_HIBER, "HIBER", BitmapValue);
    bit_test(AllPurposeHV, PCB$M_INQUAN, "INQUAN", BitmapValue);
    bit_test(AllPurposeHV, PCB$M_INTER, "INTER", BitmapValue);
    bit_test(AllPurposeHV, PCB$M_LOGIN, "LOGIN", BitmapValue);
    bit_test(AllPurposeHV, PCB$M_NETWRK, "NETWRK", BitmapValue);
    bit_test(AllPurposeHV, PCB$M_NOACNT, "NOACNT", BitmapValue);
    bit_test(AllPurposeHV, PCB$M_NODELET, "NODELET", BitmapValue);
    bit_test(AllPurposeHV, PCB$M_PHDRES, "PHDRES", BitmapValue);
    bit_test(AllPurposeHV, PCB$M_PREEMPTED, "PREEMPTED", BitmapValue);
    bit_test(AllPurposeHV, PCB$M_PSWAPM, "PSWAPM", BitmapValue);
    bit_test(AllPurposeHV, PCB$M_PWRAST, "PWRAST", BitmapValue);
    bit_test(AllPurposeHV, PCB$M_RECOVER, "RECOVER", BitmapValue);
    bit_test(AllPurposeHV, PCB$M_RES, "RES", BitmapValue);
    bit_test(AllPurposeHV, PCB$M_RESPEN, "RESPEN", BitmapValue);
    bit_test(AllPurposeHV, PCB$M_SECAUDIT, "SECAUDIT", BitmapValue);
    bit_test(AllPurposeHV, PCB$M_SOFTSUSP, "SOFTSUSP", BitmapValue);
    bit_test(AllPurposeHV, PCB$M_SSFEXC, "SSFEXC", BitmapValue);
    bit_test(AllPurposeHV, PCB$M_SSFEXCE, "SSFEXCE", BitmapValue);
    bit_test(AllPurposeHV, PCB$M_SSFEXCS, "SSFEXCS", BitmapValue);
    bit_test(AllPurposeHV, PCB$M_SSFEXCU, "SSFEXCU", BitmapValue);
    bit_test(AllPurposeHV, PCB$M_SSRWAIT, "SSRWAIT", BitmapValue);
    bit_test(AllPurposeHV, PCB$M_SUSPEN, "SUSPEN", BitmapValue);
    bit_test(AllPurposeHV, PCB$M_WAKEPEN, "WAKEPEN", BitmapValue);
    bit_test(AllPurposeHV, PCB$M_WALL, "WALL", BitmapValue);
  } else {
  if (!strcmp(InfoName, "STS2")) {
    AllPurposeHV = newHV();
    bit_test(AllPurposeHV, PCB$M_NOUNSHELVE, "NOUNSHELVE", BitmapValue);
  } else {
  if (!strcmp(InfoName, "UAF_FLAGS")) {
     AllPurposeHV = newHV();
     bit_test(AllPurposeHV, UAI$M_AUDIT, "AUDIT", BitmapValue);
     bit_test(AllPurposeHV, UAI$M_AUTOLOGIN, "AUTOLOGIN", BitmapValue);
     bit_test(AllPurposeHV, UAI$M_CAPTIVE, "CAPTIVE", BitmapValue);
     bit_test(AllPurposeHV, UAI$M_DEFCLI, "DEFCLI", BitmapValue);
     bit_test(AllPurposeHV, UAI$M_DISACNT, "DISACNT", BitmapValue);
     bit_test(AllPurposeHV, UAI$M_DISCTLY, "DISCTLY", BitmapValue);
     bit_test(AllPurposeHV, UAI$M_DISFORCE_PWD_CHANGE, "DISFORCE_PWD_CHANGE", BitmapValue);
     bit_test(AllPurposeHV, UAI$M_DISIMAGE, "DISIMAGE", BitmapValue);
     bit_test(AllPurposeHV, UAI$M_DISMAIL, "DISMAIL", BitmapValue);
     bit_test(AllPurposeHV, UAI$M_DISPWDDIC, "DISPWDDIC", BitmapValue);
     bit_test(AllPurposeHV, UAI$M_DISPWDHIS, "DISPWDHIS", BitmapValue);
     bit_test(AllPurposeHV, UAI$M_DISRECONNECT, "DISRECONNECT", BitmapValue);
     bit_test(AllPurposeHV, UAI$M_DISREPORT, "DISREPORT", BitmapValue);
     bit_test(AllPurposeHV, UAI$M_GENPWD, "GENPWD", BitmapValue);
     bit_test(AllPurposeHV, UAI$M_LOCKPWD, "LOCKPWD", BitmapValue);
     bit_test(AllPurposeHV, UAI$M_MIGRATEPWD, "MIGRATEPWD", BitmapValue);
     bit_test(AllPurposeHV, UAI$M_NOMAIL, "NOMAIL", BitmapValue);
     bit_test(AllPurposeHV, UAI$M_PWD_EXPIRED, "PWD_EXPIRED", BitmapValue);
     bit_test(AllPurposeHV, UAI$M_PWD2_EXPIRED, "PWD2_EXPIRED", BitmapValue);
     bit_test(AllPurposeHV, UAI$M_RESTRICTED , "RESTRICTED", BitmapValue);
   }}}}}}}} 
  if (AllPurposeHV) {
    ST(0) = (SV *)AllPurposeHV;
  } else {
    ST(0) = &sv_undef;
  }
}
