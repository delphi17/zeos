{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{         Interbase Database Connectivity Classes         }
{                                                         }
{        Originally written by Sergey Merkuriev           }
{                                                         }
{*********************************************************}

{@********************************************************}
{    Copyright (c) 1999-2012 Zeos Development Group       }
{                                                         }
{ License Agreement:                                      }
{                                                         }
{ This library is distributed in the hope that it will be }
{ useful, but WITHOUT ANY WARRANTY; without even the      }
{ implied warranty of MERCHANTABILITY or FITNESS FOR      }
{ A PARTICULAR PURPOSE.  See the GNU Lesser General       }
{ Public License for more details.                        }
{                                                         }
{ The source code of the ZEOS Libraries and packages are  }
{ distributed under the Library GNU General Public        }
{ License (see the file COPYING / COPYING.ZEOS)           }
{ with the following  modification:                       }
{ As a special exception, the copyright holders of this   }
{ library give you permission to link this library with   }
{ independent modules to produce an executable,           }
{ regardless of the license terms of these independent    }
{ modules, and to copy and distribute the resulting       }
{ executable under terms of your choice, provided that    }
{ you also meet, for each linked independent module,      }
{ the terms and conditions of the license of that module. }
{ An independent module is a module which is not derived  }
{ from or based on this library. If you modify this       }
{ library, you may extend this exception to your version  }
{ of the library, but you are not obligated to do so.     }
{ If you do not wish to do so, delete this exception      }
{ statement from your version.                            }
{                                                         }
{                                                         }
{ The project web site is located on:                     }
{   http://zeos.firmos.at  (FORUM)                        }
{   http://sourceforge.net/p/zeoslib/tickets/ (BUGTRACKER)}
{   svn://svn.code.sf.net/p/zeoslib/code-0/trunk (SVN)    }
{                                                         }
{   http://www.sourceforge.net/projects/zeoslib.          }
{                                                         }
{                                                         }
{                                 Zeos Development Group. }
{********************************************************@}

unit ZDbcInterbase6Utils;

interface

{$I ZDbc.inc}
uses
  SysUtils, Classes, {$IFDEF MSEgui}mclasses,{$ENDIF} Types,
  {$IF defined(UNICODE) and not defined(WITH_UNICODEFROMLOCALECHARS)}Windows,{$IFEND}
  ZDbcIntfs, ZDbcStatement, ZPlainFirebirdDriver, ZCompatibility,
  ZPlainFirebirdInterbaseConstants, ZDbcCachedResultSet, ZDbcLogging, ZMessages,
  ZVariant, ZClasses;

type
  { Interbase Statement Type }
  TZIbSqlStatementType = (stUnknown, stSelect, stInsert, stUpdate, stDelete,
    stDDL, stGetSegment, stPutSegment, stExecProc, stStartTrans, stCommit,
    stRollback, stSelectForUpdate, stSetGenerator, stDisconnect);

  { Interbase Error Class}
  EZIBConvertError = class(Exception);

  { Full info about single Interbase status entry}
  TZIBStatus = record
    IBDataType: Integer; // one of isc_arg_* constants
    IBDataInt: Integer;  // int data (error code)
    IBDataStr: string;   // string data
    IBMessage: string;   // result of isc_interpret
    SQLCode: Integer;    // result of isc_sqlcode
    SQLMessage: string;  // result of isc_sql_interprete
  end;
  PZIBStatus = ^TZIBStatus;

  TZIBStatusVector = array of TZIBStatus;

  { IB/FB-specific data}
  TZIBSpecificData = class(TZExceptionSpecificData)
  protected
    FStatusVector: TZIBStatusVector;
    FSQL: string;
    FIBErrorCode: Integer;
    FIBStatusCode: String;
  public
    function Clone: TZExceptionSpecificData; override;

    property IBErrorCode: Integer read FIBErrorCode;
    property IBStatusCode: string read FIBStatusCode;
    property StatusVector: TZIBStatusVector read FStatusVector;
    property SQL: string read FSQL;
  end;

  { Interbase SQL Error Class}
  EZIBSQLException = class(EZSQLException)
  public
    constructor Create(const Msg: string; const StatusVector: TZIBStatusVector; const SQL: string);
  end;

  TZIbParamValueType = (
    pvtNotImpl,  // unsupported
    pvtNone,     // no value
    pvtByteZ,    // 1-byte int that always = 0 (value ignored)
    pvtNum,      // 1/2/4-byte int, depending on a value
    pvtString    // raw byte string
  );

  { Paparameter string name and it value}
  TZIbParam = record
    Name: String;
    ValueType: TZIbParamValueType;
    Number: word;
  end;
  PZIbParam = ^TZIbParam;

  { Interbase blob Information structure
    contain iformation about blob size in bytes,
    segments count, segment size in bytes and blob type
    Note: blob type can be text and binary }
  TIbBlobInfo = record
    NumSegments: Word;
    MaxSegmentSize: Word;
    BlobType: SmallInt;
    TotalSize: LongInt;
  end;

  { Base interface for sqlda }
  IZSQLDA = interface
    ['{2D0D6029-B31C-4E39-89DC-D86D20437C35}']
    procedure InitFields(Parameters: boolean);
    procedure AllocateSQLDA;
    procedure FreeParamtersValues;

    function GetData: PXSQLDA;
    function IsBlob(const Index: Word): boolean;
    function IsNullable(const Index: Word): boolean;

    function GetFieldCount: Integer;
    function GetFieldSqlName(const Index: Word): String;
    function GetFieldRelationName(const Index: Word): String;
    function GetFieldOwnerName(const Index: Word): String;
    function GetFieldAliasName(const Index: Word): String;
    function GetFieldIndex(const Name: String): Word;
    function GetFieldScale(const Index: Word): integer;
    function GetFieldSqlType(const Index: Word): TZSQLType;
    function GetFieldLength(const Index: Word): SmallInt;
    function GetIbSqlType(const Index: Word): Smallint;
    function GetIbSqlSubType(const Index: Word): Smallint;
    function GetIbSqlLen(const Index: Word): Smallint;
  end;

  { parameters interface sqlda}
  IZParamsSQLDA = interface(IZSQLDA)
    ['{D2C3D5E1-F3A6-4223-9A6E-3048B99A06C4}']
    procedure WriteLobBuffer(const Index: Integer; const Buffer: Pointer; const Len: Integer);
    procedure UpdateNull(const Index: Integer; const Value: boolean);
    procedure UpdateBoolean(const Index: Integer; const Value: boolean);
    procedure UpdateSmall(const Index: Integer; const Value: SmallInt);
    procedure UpdateInt(const Index: Integer; const Value: Integer);
    procedure UpdateLong(const Index: Integer; const Value: Int64);
    procedure UpdateFloat(const Index: Integer; const Value: Single);
    procedure UpdateDouble(const Index: Integer; const Value: Double);
    procedure UpdateBigDecimal(const Index: Integer; const Value: Extended);
    procedure UpdatePAnsiChar(const Index: Integer; const Value: PAnsiChar; const Len: Cardinal);
    procedure UpdateBytes(const Index: Integer; const Value: TBytes);
    procedure UpdateDate(const Index: Integer; const Value: TDateTime);
    procedure UpdateTime(const Index: Integer; const Value: TDateTime);
    procedure UpdateTimestamp(const Index: Integer; const Value: TDateTime);
    procedure UpdateQuad(const Index: Word; const Value: TISC_QUAD);
    procedure UpdateArray(const Index: Word; const Value; const SQLType: TZSQLType;
      const VariantType: TZVariantType = vtNull);
    function GetAsLogValue(Index: Word): RawByteString;
  end;

  { Base class contain core functions to work with sqlda structure
    Can allocate memory for sqlda structure get basic information }

  TZSQLDA = class (TZCodePagedObject, IZSQLDA, IImmediatelyReleasable)
  private
    FXSQLDA: PXSQLDA;
    FPlainDriver: TZInterbasePlainDriver;
    FConnection: IZConnection;
    FDecribedLengthArray: TSmallIntDynArray;
    FDecribedScaleArray: TSmallIntDynArray;
    FDecribedTypeArray: TSmallIntDynArray;
    procedure CheckRange(const Index: Word); {$IFDEF WITH_INLINE}inline;{$ENDIF}
    procedure IbReAlloc(var P; OldSize, NewSize: Integer);
    procedure SetFieldType(const Index: Word; Size: Integer; Code: Smallint;
      Scale: Smallint);
  public
    constructor Create(const Connection: IZConnection);
    destructor Destroy; override;
    procedure InitFields(Parameters: boolean);
    procedure AllocateSQLDA;
    procedure FreeParamtersValues;

    function IsBlob(const Index: Word): boolean;
    function IsNullable(const Index: Word): boolean;

    function GetFieldCount: Integer;
    function GetFieldSqlName(const Index: Word): String;
    function GetFieldOwnerName(const Index: Word): String;
    function GetFieldRelationName(const Index: Word): String;
    function GetFieldAliasName(const Index: Word): String;
    function GetFieldIndex(const Name: String): Word;
    function GetFieldScale(const Index: Word): integer;
    function GetFieldSqlType(const Index: Word): TZSQLType;
    function GetFieldLength(const Index: Word): SmallInt;
    function GetData: PXSQLDA;

    function GetIbSqlType(const Index: Word): Smallint;
    function GetIbSqlSubType(const Index: Word): Smallint;
    function GetIbSqlLen(const Index: Word): Smallint;

    procedure ReleaseImmediat(const Sender: IImmediatelyReleasable);
  end;

  { Parameters class for sqlda structure.
    It clas can only write data to parameters/fields }
  TZParamsSQLDA = class (TZSQLDA, IZParamsSQLDA)
  private
    procedure EncodeString(const Code: Smallint; const Index: Word; const Str: RawByteString);
    procedure EncodePData(Code: Smallint; Index: Word; Value: PAnsiChar; Len: LengthInt);
    procedure UpdateDateTime(const Index: Integer; const Value: TDateTime);
  public
    procedure WriteLobBuffer(const Index: Integer; const Buffer: Pointer; const Len: Integer);

    procedure UpdateNull(const Index: Integer; const Value: boolean);
    procedure UpdateBoolean(const Index: Integer; const Value: boolean);
    procedure UpdateSmall(const Index: Integer; const Value: SmallInt);
    procedure UpdateInt(const Index: Integer; const Value: Integer);
    procedure UpdateLong(const Index: Integer; const Value: Int64);
    procedure UpdateFloat(const Index: Integer; const Value: Single);
    procedure UpdateDouble(const Index: Integer; const Value: Double);
    procedure UpdateBigDecimal(const Index: Integer; const Value: Extended);
    procedure UpdatePAnsiChar(const Index: Integer; const Value: PAnsiChar; const Len: Cardinal);
    procedure UpdateBytes(const Index: Integer; const Value: TBytes);
    procedure UpdateDate(const Index: Integer; const Value: TDateTime);
    procedure UpdateTime(const Index: Integer; const Value: TDateTime);
    procedure UpdateTimestamp(const Index: Integer; const Value: TDateTime);
    procedure UpdateQuad(const Index: Word; const Value: TISC_QUAD);
    procedure UpdateArray(const Index: Word; const {%H-}Value; const {%H-}SQLType: TZSQLType;
      const {%H-}VariantType: TZVariantType = vtNull);
    function GetAsLogValue(Index: Word): RawByteString;
  end;

function CreateIBResultSet(const SQL: string; const Statement: IZStatement;
  const NativeResultSet: IZResultSet): IZResultSet;

{Interbase6 Connection Functions}
function GenerateDPB(PlainDriver: TZInterbasePlainDriver; Info: TStrings;
  ConSettings: PZConSettings; CP: Word): RawByteString;
function GenerateTPB(PlainDriver: TZInterbasePlainDriver; Params: TStrings;
  ConSettings: PZConSettings; CP: Word): RawByteString;
procedure GenerateTEB(PHandle: PISC_DB_HANDLE; const TPB: RawByteString; var TEB: TISC_TEB);
function GetInterbase6DatabaseParamNumber(const Value: String): word;
function GetInterbase6TransactionParamNumber(const Value: String): word;

{ Interbase6 errors functions }
function GetNameSqlType(Value: Word): RawByteString;
function StatusSucceeded(const StatusVector: TARRAY_ISC_STATUS): Boolean; {$IFDEF WITH_INLINE}inline;{$ENDIF}
function InterpretInterbaseStatus(const PlainDriver: TZInterbasePlainDriver;
  const StatusVector: TARRAY_ISC_STATUS;
  const ConSettings: PZConSettings) : TZIBStatusVector;
procedure CheckInterbase6Error(const PlainDriver: TZInterbasePlainDriver;
  const StatusVector: TARRAY_ISC_STATUS; const ImmediatelyReleasable: IImmediatelyReleasable;
  const LoggingCategory: TZLoggingCategory = lcOther;
  const SQL: RawByteString = '');

{ Interbase information functions}
function GetDBStringInfo(const PlainDriver: TZInterbasePlainDriver;
  Handle: PISC_DB_HANDLE; isc_info: Byte; const ImmediatelyReleasable: IImmediatelyReleasable): String;
function GetDBIntegerInfo(const PlainDriver: TZInterbasePlainDriver;
  Handle: PISC_DB_HANDLE; isc_info: Byte; const ImmediatelyReleasable: IImmediatelyReleasable): LongInt;
function GetDBSQLDialect(const PlainDriver: TZInterbasePlainDriver;
  const Handle: PISC_DB_HANDLE; const ImmediatelyReleasable: IImmediatelyReleasable): Integer;

{ Interbase statement functions}
function PrepareStatement(const PlainDriver: TZInterbasePlainDriver;
  Handle: PISC_DB_HANDLE; TrHandle: PISC_TR_HANDLE;
  Dialect: Word; const SQL: RawByteString; const ImmediatelyReleasable: IImmediatelyReleasable;
  var StmtHandle: TISC_STMT_HANDLE): TZIbSqlStatementType;
procedure PrepareResultSqlData(const PlainDriver: TZInterbasePlainDriver;
  const Dialect: Word; const SQL: RawByteString;
  var StmtHandle: TISC_STMT_HANDLE; const SqlData: IZSQLDA;
  const ImmediatelyReleasable: IImmediatelyReleasable); overload;
procedure BindSQLDAInParameters(BindList: TZBindList; const ParamSqlData: IZParamsSQLDA;
  const ConSettings: PZConSettings; const CodePageArray: TWordDynArray;
  ArrayOffSet, ArrayItersCount: Integer);
procedure FreeStatement(const PlainDriver: TZInterbasePlainDriver;
  StatementHandle: TISC_STMT_HANDLE; Options : Word);
function GetStatementType(const PlainDriver: TZInterbasePlainDriver;
  const StmtHandle: TISC_STMT_HANDLE; const ImmediatelyReleasable: IImmediatelyReleasable): TZIbSqlStatementType;
function GetAffectedRows(const PlainDriver: TZInterbasePlainDriver;
  const StmtHandle: TISC_STMT_HANDLE; const StatementType: TZIbSqlStatementType;
  const ImmediatelyReleasable: IImmediatelyReleasable): integer;

function ConvertInterbase6ToSqlType(const SqlType, SqlSubType, Scale: Integer;
  const CtrlsCPType: TZControlsCodePage): TZSqlType;

{ interbase blob routines }
procedure GetBlobInfo(const PlainDriver: TZInterbasePlainDriver;
  const BlobHandle: TISC_BLOB_HANDLE; out BlobInfo: TIbBlobInfo;
  const ImmediatelyReleasable: IImmediatelyReleasable);
procedure ReadBlobBufer(const PlainDriver: TZInterbasePlainDriver;
  const Handle: PISC_DB_HANDLE; const TransactionHandle: PISC_TR_HANDLE;
  const BlobId: TISC_QUAD; out Size: Integer; out Buffer: Pointer;
  const Binary: Boolean; const ImmediatelyReleasable: IImmediatelyReleasable);

function GetExecuteBlockString(const ParamsSQLDA: IZParamsSQLDA;
  const IsParamIndexArray: TBooleanDynArray;
  const InParamCount, RemainingArrayRows: Integer;
  const CurrentSQLTokens: TRawByteStringDynArray;
  const PlainDriver: TZInterbasePlainDriver;
  var MemPerRow, PreparedRowsOfArray, MaxRowsPerBatch: Integer;
  var TypeTokens: TRawByteStringDynArray;
  InitialStatementType: TZIbSqlStatementType;
  const XSQLDAMaxSize: LongWord): RawByteString;

const
  { Default Interbase blob size for reading }
  DefaultBlobSegmentSize = 16 * 1024;

  IBScaleDivisor: array[-18..-1] of Int64 = (
    {sqldialect 3 range 1..18}
    1000000000000000000,
    100000000000000000,
    10000000000000000,
    {sqldialect 1 range 1..15}
    1000000000000000,
    100000000000000,
    10000000000000,
    1000000000000,
    100000000000,
    10000000000,
    1000000000,
    100000000,
    10000000,1000000,100000,10000,1000,100,10);

  { count database parameters }
  MAX_DPB_PARAMS = 90;
  { prefix database parameters names it used in paramters scann procedure }
  DPBPrefix = 'isc_dpb_';
  { list database parameters and their apropriate numbers }
  DatabaseParams: array [0..MAX_DPB_PARAMS-1] of TZIbParam =
  (
    (Name: 'isc_dpb_cdd_pathname';          ValueType: pvtNotImpl; Number: isc_dpb_cdd_pathname),
    (Name: 'isc_dpb_allocation';            ValueType: pvtNotImpl; Number: isc_dpb_allocation),
    (Name: 'isc_dpb_journal';               ValueType: pvtNotImpl; Number: isc_dpb_journal),
    (Name: 'isc_dpb_page_size';             ValueType: pvtNum;     Number: isc_dpb_page_size),
    (Name: 'isc_dpb_num_buffers';           ValueType: pvtNum;     Number: isc_dpb_num_buffers),
    (Name: 'isc_dpb_buffer_length';         ValueType: pvtNotImpl; Number: isc_dpb_buffer_length),
    (Name: 'isc_dpb_debug';                 ValueType: pvtNum;     Number: isc_dpb_debug),
    (Name: 'isc_dpb_garbage_collect';       ValueType: pvtNone;    Number: isc_dpb_garbage_collect),
    (Name: 'isc_dpb_verify';                ValueType: pvtNum;     Number: isc_dpb_verify),    // Bitmask
    (Name: 'isc_dpb_sweep';                 ValueType: pvtNum;     Number: isc_dpb_sweep),
    (Name: 'isc_dpb_enable_journal';        ValueType: pvtString;  Number: isc_dpb_enable_journal),
    (Name: 'isc_dpb_disable_journal';       ValueType: pvtNone;    Number: isc_dpb_disable_journal),
    (Name: 'isc_dpb_dbkey_scope';           ValueType: pvtNum;     Number: isc_dpb_dbkey_scope),
    (Name: 'isc_dpb_number_of_users';       ValueType: pvtNotImpl; Number: isc_dpb_number_of_users),
    (Name: 'isc_dpb_trace';                 ValueType: pvtNone;    Number: isc_dpb_trace),
    (Name: 'isc_dpb_no_garbage_collect';    ValueType: pvtNone;    Number: isc_dpb_no_garbage_collect),
    (Name: 'isc_dpb_damaged';               ValueType: pvtNum;     Number: isc_dpb_damaged),
    (Name: 'isc_dpb_license';               ValueType: pvtString;  Number: isc_dpb_license),
    (Name: 'isc_dpb_sys_user_name';         ValueType: pvtString;  Number: isc_dpb_sys_user_name),
    (Name: 'isc_dpb_encrypt_key';           ValueType: pvtString;  Number: isc_dpb_encrypt_key),
    (Name: 'isc_dpb_activate_shadow';       ValueType: pvtByteZ;   Number: isc_dpb_activate_shadow),
    (Name: 'isc_dpb_sweep_interval';        ValueType: pvtNum;     Number: isc_dpb_sweep_interval),
    (Name: 'isc_dpb_delete_shadow';         ValueType: pvtByteZ;   Number: isc_dpb_delete_shadow),
    (Name: 'isc_dpb_force_write';           ValueType: pvtNum;     Number: isc_dpb_force_write),
    (Name: 'isc_dpb_begin_log';             ValueType: pvtString;  Number: isc_dpb_begin_log),
    (Name: 'isc_dpb_quit_log';              ValueType: pvtNone;    Number: isc_dpb_quit_log),
    (Name: 'isc_dpb_no_reserve';            ValueType: pvtNum;     Number: isc_dpb_no_reserve),
    (Name: 'isc_dpb_username';              ValueType: pvtString;  Number: isc_dpb_user_name),
    (Name: 'isc_dpb_password';              ValueType: pvtString;  Number: isc_dpb_password),
    (Name: 'isc_dpb_password_enc';          ValueType: pvtString;  Number: isc_dpb_password_enc),
    (Name: 'isc_dpb_sys_user_name_enc';     ValueType: pvtString;  Number: isc_dpb_sys_user_name_enc),
    (Name: 'isc_dpb_interp';                ValueType: pvtNum;     Number: isc_dpb_interp),
    (Name: 'isc_dpb_online_dump';           ValueType: pvtNum;     Number: isc_dpb_online_dump),
    (Name: 'isc_dpb_old_file_size';         ValueType: pvtNum;     Number: isc_dpb_old_file_size),
    (Name: 'isc_dpb_old_num_files';         ValueType: pvtNum;     Number: isc_dpb_old_num_files),
    (Name: 'isc_dpb_old_file';              ValueType: pvtString;  Number: isc_dpb_old_file),
    (Name: 'isc_dpb_old_start_page';        ValueType: pvtNum;     Number: isc_dpb_old_start_page),
    (Name: 'isc_dpb_old_start_seqno';       ValueType: pvtNum;     Number: isc_dpb_old_start_seqno),
    (Name: 'isc_dpb_old_start_file';        ValueType: pvtNum;     Number: isc_dpb_old_start_file),
    (Name: 'isc_dpb_drop_walfile';          ValueType: pvtNum;     Number: isc_dpb_drop_walfile),
    (Name: 'isc_dpb_old_dump_id';           ValueType: pvtNum;     Number: isc_dpb_old_dump_id),
    (Name: 'isc_dpb_wal_backup_dir';        ValueType: pvtString;  Number: isc_dpb_wal_backup_dir),
    (Name: 'isc_dpb_wal_chkptlen';          ValueType: pvtNum;     Number: isc_dpb_wal_chkptlen),
    (Name: 'isc_dpb_wal_numbufs';           ValueType: pvtNum;     Number: isc_dpb_wal_numbufs),
    (Name: 'isc_dpb_wal_bufsize';           ValueType: pvtNum;     Number: isc_dpb_wal_bufsize),
    (Name: 'isc_dpb_wal_grp_cmt_wait';      ValueType: pvtNum;     Number: isc_dpb_wal_grp_cmt_wait),
    (Name: 'isc_dpb_lc_messages';           ValueType: pvtString;  Number: isc_dpb_lc_messages),
    (Name: 'isc_dpb_lc_ctype';              ValueType: pvtString;  Number: isc_dpb_lc_ctype),
    (Name: 'isc_dpb_cache_manager';         ValueType: pvtNotImpl; Number: isc_dpb_cache_manager),
    (Name: 'isc_dpb_shutdown';              ValueType: pvtNum;     Number: isc_dpb_shutdown), // Bitmask
    (Name: 'isc_dpb_online';                ValueType: pvtNone;    Number: isc_dpb_online),
    (Name: 'isc_dpb_shutdown_delay';        ValueType: pvtNum;     Number: isc_dpb_shutdown_delay),
    (Name: 'isc_dpb_reserved';              ValueType: pvtNone;    Number: isc_dpb_reserved),
    (Name: 'isc_dpb_overwrite';             ValueType: pvtNone;    Number: isc_dpb_overwrite),
    (Name: 'isc_dpb_sec_attach';            ValueType: pvtNone;    Number: isc_dpb_sec_attach),
    (Name: 'isc_dpb_disable_wal';           ValueType: pvtNone;    Number: isc_dpb_disable_wal),
    (Name: 'isc_dpb_connect_timeout';       ValueType: pvtNum;     Number: isc_dpb_connect_timeout),
    (Name: 'isc_dpb_dummy_packet_interval'; ValueType: pvtNum;     Number: isc_dpb_dummy_packet_interval),
    (Name: 'isc_dpb_gbak_attach';           ValueType: pvtNone;    Number: isc_dpb_gbak_attach),
    (Name: 'isc_dpb_sql_role_name';         ValueType: pvtString;  Number: isc_dpb_sql_role_name),
    (Name: 'isc_dpb_set_page_buffers';      ValueType: pvtNum;     Number: isc_dpb_set_page_buffers),
    (Name: 'isc_dpb_working_directory';     ValueType: pvtString;  Number: isc_dpb_working_directory),
    (Name: 'isc_dpb_sql_dialect';           ValueType: pvtNum;     Number: isc_dpb_SQL_dialect),
    (Name: 'isc_dpb_set_db_readonly';       ValueType: pvtNone;    Number: isc_dpb_set_db_readonly),
    (Name: 'isc_dpb_set_db_sql_dialect';    ValueType: pvtNum;     Number: isc_dpb_set_db_SQL_dialect),
    (Name: 'isc_dpb_gfix_attach';           ValueType: pvtNone;    Number: isc_dpb_gfix_attach),
    (Name: 'isc_dpb_gstat_attach';          ValueType: pvtNone;    Number: isc_dpb_gstat_attach),
    (Name: 'isc_dpb_set_db_charset';        ValueType: pvtString;  Number: isc_dpb_set_db_charset),
    (Name: 'isc_dpb_gsec_attach';           ValueType: pvtNone;    Number: isc_dpb_gsec_attach),
    (Name: 'isc_dpb_address_path';          ValueType: pvtString;  Number: isc_dpb_address_path),
    (Name: 'isc_dpb_process_id';            ValueType: pvtNum;     Number: isc_dpb_process_id),
    (Name: 'isc_dpb_no_db_triggers';        ValueType: pvtNone;    Number: isc_dpb_no_db_triggers),
    (Name: 'isc_dpb_trusted_auth';          ValueType: pvtNone;    Number: isc_dpb_trusted_auth),
    (Name: 'isc_dpb_process_name';          ValueType: pvtString;  Number: isc_dpb_process_name),
    (Name: 'isc_dpb_trusted_role';          ValueType: pvtString;  Number: isc_dpb_trusted_role),
    (Name: 'isc_dpb_org_filename';          ValueType: pvtString;  Number: isc_dpb_org_filename),
    (Name: 'isc_dpb_utf8_filename';         ValueType: pvtNone;    Number: isc_dpb_utf8_filename),
    (Name: 'isc_dpb_ext_call_depth';        ValueType: pvtNum;     Number: isc_dpb_ext_call_depth),
    (Name: 'isc_dpb_auth_block';            ValueType: pvtString; Number: isc_dpb_auth_block), // Bytes
    (Name: 'isc_dpb_client_version';        ValueType: pvtString; Number: isc_dpb_client_version),
    (Name: 'isc_dpb_remote_protocol';       ValueType: pvtString; Number: isc_dpb_remote_protocol),
    (Name: 'isc_dpb_host_name';             ValueType: pvtString; Number: isc_dpb_host_name),
    (Name: 'isc_dpb_os_user';               ValueType: pvtString; Number: isc_dpb_os_user),
    (Name: 'isc_dpb_specific_auth_data';    ValueType: pvtString; Number: isc_dpb_specific_auth_data),  
    (Name: 'isc_dpb_auth_plugin_list';      ValueType: pvtString; Number: isc_dpb_auth_plugin_list),  
    (Name: 'isc_dpb_auth_plugin_name';      ValueType: pvtString; Number: isc_dpb_auth_plugin_name),
    (Name: 'isc_dpb_config';                ValueType: pvtString; Number: isc_dpb_config),
    (Name: 'isc_dpb_nolinger';              ValueType: pvtNone; Number: isc_dpb_nolinger),
    (Name: 'isc_dpb_reset_icu';             ValueType: pvtNone; Number: isc_dpb_reset_icu),
    (Name: 'isc_dpb_map_attach';            ValueType: pvtNone; Number: isc_dpb_map_attach)
  );

  { count transaction parameters }
  MAX_TPB_PARAMS = 22;
  { prefix transaction parameters names it used in paramters scann procedure }
  TPBPrefix = 'isc_tpb_';
  { list transaction parameters and their apropriate numbers }
  TransactionParams: array [0..MAX_TPB_PARAMS-1] of TZIbParam =
  (
    (Name: 'isc_tpb_consistency';      ValueType: pvtNone;    Number: isc_tpb_consistency),
    (Name: 'isc_tpb_concurrency';      ValueType: pvtNone;    Number: isc_tpb_concurrency),
    (Name: 'isc_tpb_shared';           ValueType: pvtNone;    Number: isc_tpb_shared),
    (Name: 'isc_tpb_protected';        ValueType: pvtNone;    Number: isc_tpb_protected),
    (Name: 'isc_tpb_exclusive';        ValueType: pvtNone;    Number: isc_tpb_exclusive),
    (Name: 'isc_tpb_wait';             ValueType: pvtNone;    Number: isc_tpb_wait),
    (Name: 'isc_tpb_nowait';           ValueType: pvtNone;    Number: isc_tpb_nowait),
    (Name: 'isc_tpb_read';             ValueType: pvtNone;    Number: isc_tpb_read),
    (Name: 'isc_tpb_write';            ValueType: pvtNone;    Number: isc_tpb_write),
    (Name: 'isc_tpb_lock_read';        ValueType: pvtString;  Number: isc_tpb_lock_read),
    (Name: 'isc_tpb_lock_write';       ValueType: pvtString;  Number: isc_tpb_lock_write),
    (Name: 'isc_tpb_verb_time';        ValueType: pvtNotImpl; Number: isc_tpb_verb_time),
    (Name: 'isc_tpb_commit_time';      ValueType: pvtNotImpl; Number: isc_tpb_commit_time),
    (Name: 'isc_tpb_ignore_limbo';     ValueType: pvtNone;    Number: isc_tpb_ignore_limbo),
    (Name: 'isc_tpb_read_committed';   ValueType: pvtNone;    Number: isc_tpb_read_committed),
    (Name: 'isc_tpb_autocommit';       ValueType: pvtNone;    Number: isc_tpb_autocommit),
    (Name: 'isc_tpb_rec_version';      ValueType: pvtNone;    Number: isc_tpb_rec_version),
    (Name: 'isc_tpb_no_rec_version';   ValueType: pvtNone;    Number: isc_tpb_no_rec_version),
    (Name: 'isc_tpb_restart_requests'; ValueType: pvtNone;    Number: isc_tpb_restart_requests),
    (Name: 'isc_tpb_no_auto_undo';     ValueType: pvtNone;    Number: isc_tpb_no_auto_undo),
    // IB75+
    (Name: 'isc_tpb_no_savepoint';     ValueType: pvtNone;    Number: isc_tpb_no_savepoint),
    // FB20+
    (Name: 'isc_tpb_lock_timeout';     ValueType: pvtNum;     Number: isc_tpb_lock_timeout)
  );

//ported  from NoThrowTimeStamp.cpp

procedure isc_decode_time(ntime: ISC_TIME; out hours, minutes, seconds: Word; out fractions: LongWord);
procedure isc_encode_time(var ntime: ISC_TIME; hours, minutes, seconds: Word; fractions: LongWord);
procedure isc_decode_date(nday: ISC_DATE; out year, month, day: Word);
procedure isc_encode_date(out nday: ISC_DATE; year, month, day: Word);

implementation

uses
  ZFastCode, Variants, ZSysUtils, Math, ZDbcInterbase6, ZDbcUtils, ZEncoding
  {$IFDEF WITH_UNITANSISTRINGS}, AnsiStrings{$ENDIF};

{**
  Create CachedResultSet with using TZCachedResultSet and return it.
  @param SQL a sql query command
  @param Statement a zeos statement object
  @param NativeResultSet a native result set
  @return cached ResultSet if rcReadOnly <> rcReadOnly
}
function CreateIBResultSet(const SQL: string; const Statement: IZStatement;
  const NativeResultSet: IZResultSet): IZResultSet;
var
  CachedResolver: TZInterbase6CachedResolver;
  CachedResultSet: TZCachedResultSet;
begin
  if (Statement.GetResultSetConcurrency = rcUpdatable)
    or (Statement.GetResultSetType <> rtForwardOnly) then
  begin
    CachedResolver  := TZInterbase6CachedResolver.Create(Statement,  NativeResultSet.GetMetadata);
    CachedResultSet := TZCachedResultSet.Create(NativeResultSet, SQL,
      CachedResolver, Statement.GetConnection.GetConSettings);
    CachedResultSet.SetConcurrency(Statement.GetResultSetConcurrency);
    Result := CachedResultSet;
  end
  else
    Result := NativeResultSet;
end;

function FindPBParam(const ParamName: string; const ParamArr: array of TZIbParam): PZIbParam;
var
  I: Integer;
begin
  for I := Low(ParamArr) to High(ParamArr) do
    if ParamName = ParamArr[I].Name then
    begin
      Result := @ParamArr[I];
      Exit;
    end;
  Result := nil;
end;

{**
  Build parameter block string

  @param PlainDriver - a Interbase Plain drver
  @param Info - a list connection interbase parameters
  @param VersionCode - isc_dpb_version1 for TPB or isc_dpb_version3 for DPB
  @param FilterPrefix - TPBPrefix for TPB or DPBPrefix for DPB
  @param ParamArr - array of parameter properties

  @return generated string
}
function BuildPB(PlainDriver: TZInterbasePlainDriver; Info: TStrings; VersionCode: Byte;
  const FilterPrefix: string; const ParamArr: array of TZIbParam;
  ConSettings: PZConSettings; CP: Word): RawByteString;
var Buf: TRawBuff;

  procedure ExtractParamNameAndValue(const S: string; out ParamName: String; out ParamValue: String);
  var
    Pos: Integer;
  begin
    Pos := FirstDelimiter(' ='#9#10#13, S);
    if Pos = 0 then
    begin
      ParamName := S;
      ParamValue := '';
    end
    else
    begin
      ParamName := Trim(LowerCase(Copy(S, 1, Pos - 1)));
      ParamValue := Trim(Copy(S, Pos + 1, MaxInt));
    end;
  end;

  procedure NumToPB(Value: Cardinal);
  var Len: Smallint;
  begin
    case Value of
      0..High(Byte):
        begin
          Len := 1;
          ToBuff(AnsiChar(Len), Buf, Result);
          ToBuff(AnsiChar(Byte(Value)), Buf, Result);
        end;
      High(Byte)+1..High(Word):
        begin
          Len := 2;
          ToBuff(AnsiChar(Len), Buf, Result);
          PWord(@Value)^ := Word(Value);
          PWord(@Value)^ := Word(PlainDriver.isc_vax_integer(@Value, Len));
          ToBuff(@Value, Len, Buf, Result);
        end;
      else
        begin
          Len := 4;
          ToBuff(AnsiChar(Len), Buf, Result);
          Value := Cardinal(PlainDriver.isc_vax_integer(@Value, Len));
          ToBuff(@Value, Len, Buf, Result);
        end;
    end;
  end;

var
  I, IntValue: Integer;
  ParamName: String;
  ParamValue: String;
  tmp: RawByteString;
  PParam: PZIbParam;
begin
  Buf.Buf[0] := AnsiChar(VersionCode);
  Buf.Pos := 1;
  Result := EmptyRaw;
  for I := 0 to Info.Count - 1 do
  begin
    ExtractParamNameAndValue(Info.Strings[I], ParamName, ParamValue);
    if ZFastCode.Pos(FilterPrefix, ParamName) <> 1 then
      Continue;
    PParam := FindPBParam(ParamName, ParamArr);
    if PParam = nil then
      raise EZSQLException.CreateFmt('Unknown PB parameter "%s"', [ParamName]);

    case PParam.ValueType of
      pvtNone:
        if VersionCode = isc_tpb_version3 then
          ToBuff(AnsiChar(PParam.Number), Buf, Result)
        else
        begin
          ToBuff(AnsiChar(PParam.Number), Buf, Result);
          ToBuff(AnsiChar(#0), Buf, Result);
        end;
      pvtByteZ:
        begin
          ToBuff(AnsiChar(PParam.Number), Buf, Result);
          ToBuff(AnsiChar(#1), Buf, Result);
          ToBuff(AnsiChar(#0), Buf, Result);
        end;
      pvtNum:
        begin
          ToBuff(AnsiChar(PParam.Number), Buf, Result);
          IntValue := StrToInt(ParamValue);
          NumToPB(IntValue);
        end;
      pvtString:
        begin
          tmp := ConSettings.ConvFuncs.ZStringToRaw(ParamValue, ConSettings^.CTRL_CP, CP);
          ToBuff(AnsiChar(PParam.Number), Buf, Result);
          ToBuff(AnsiChar(Length(tmp)), Buf, Result);
          ToBuff(tmp, Buf, Result);
        end;
    end;
  end;
  FlushBuff(Buf, Result);
end;

{**
  Generate database connection string by connection information

  @param PlainDriver - a Interbase Plain drver
  @param Info - a list connection interbase parameters
  @return a generated string
}
function GenerateDPB(PlainDriver: TZInterbasePlainDriver; Info: TStrings;
  ConSettings: PZConSettings; CP: Word): RawByteString;
begin
  Result := BuildPB(PlainDriver, Info, isc_dpb_version1, DPBPrefix, DatabaseParams, ConSettings, CP);
end;

{**
  Generate transaction string by connection information

  @param PlainDriver - a Interbase Plain drver
  @param Params - a transaction parameters list
  @return a generated string
}
function GenerateTPB(PlainDriver: TZInterbasePlainDriver; Params: TStrings;
  ConSettings: PZConSettings; CP: Word): RawByteString;
begin
  Result := BuildPB(PlainDriver, Params, isc_tpb_version3, TPBPrefix, TransactionParams, ConSettings, CP);
end;

{**
  Generate transaction structure by connection information

  @param PHandle - pointer to database connection handle
  @param TPB - transaction parameter string
  @param TEB a transaction ISC structure
}
procedure GenerateTEB(PHandle: PISC_DB_HANDLE; const TPB: RawByteString; var TEB: TISC_TEB);
begin
  TEB.db_handle := PHandle;
  TEB.tpb_length := Length(TPB);
  TEB.tpb_address := Pointer(TPB);
end;

function GetPBNumber(const FilterPrefix, ParamName: string; const ParamArr: array of TZIbParam): Word;
var
  pParam: PZIbParam;
  ParamNameLO: String;
begin
  ParamNameLO := LowerCase(ParamName);
  Result := 0;
  if ZFastCode.Pos(FilterPrefix, ParamNameLO) = 1 then
  begin
    pParam := FindPBParam(ParamNameLO, ParamArr);
    if pParam <> nil then
      Result := pParam^.Number;
  end;
end;

{**
  Return interbase connection parameter number by it name
  @param Value - a connection parameter name
  @return - connection parameter number
}
function GetInterbase6DatabaseParamNumber(const Value: String): Word;
begin
  Result := GetPBNumber(DPBPrefix, Value, DatabaseParams);
end;

{**
  Return interbase transaction parameter number by it name
  @param Value - a transaction parameter name
  @return - transaction parameter number
}
function GetInterbase6TransactionParamNumber(const Value: String): Word;
begin
  Result := GetPBNumber(TPBPrefix, Value, TransactionParams);
end;

{**
  Read Interbase number (1..4 bytes) from buffer in standard format: [Len * 2 bytes][Number * Len bytes]
  and increments buffer pointer skipping read data.
  @param PlainDriver a Interbase Plain drver
  @param pBuf - pointer to a buffer returned by driver. After the function it points to the next block.
  @return - a number read
}
function ReadInterbase6NumberWithInc(const PlainDriver: TZInterbasePlainDriver; var pBuf: PAnsiChar): Integer;
var
  Len: Integer;
begin
  Len := PlainDriver.isc_vax_integer(pBuf, 2);
  Inc(pBuf, 2);
  Result := PlainDriver.isc_vax_integer(pBuf, Len);
  Inc(pBuf, Len);
end;

{**
  Read Interbase number (1..4 bytes) from buffer in standard format: [Len * 2 bytes][Number * Len bytes].
  Function accepts constant pointer for easier usage with single reads.
  @param PlainDriver a Interbase Plain drver
  @param Buffer - a buffer returned by driver
  @return - a number read
}
function ReadInterbase6Number(const PlainDriver: TZInterbasePlainDriver; const Buffer): Integer; {$IFDEF WITH_INLINE} inline;{$ENDIF}
var
  pBuf: PAnsiChar;
begin
  pBuf := @Buffer;
  Result := ReadInterbase6NumberWithInc(PlainDriver, pBuf);
end;

{**
  Converts a Interbase6 native types into ZDBC SQL types.
  @param the interbase type
  @param the interbase subtype
  @return a SQL undepended type.

  <b>Note:</b> The interbase type and subtype get from RDB$TYPES table
}
function ConvertInterbase6ToSqlType(const SqlType, SqlSubType, Scale: Integer;
  const CtrlsCPType: TZControlsCodePage): TZSQLType;
begin
  Result := ZDbcIntfs.stUnknown;

  case SqlType of
    blr_bool, blr_not_nullable: Result := stBoolean;
    blr_domain_name, blr_domain_name2,
    blr_column_name, blr_column_name2:
      Result := stString;
    blr_varying2, blr_varying,
    blr_text, blr_text2,
    blr_cstring, blr_cstring2:
      case SqlSubType of
        CS_BINARY: Result := stBytes;
      else
        Result := stString;
      end;
    blr_d_float: Result := stDouble;
    blr_float: Result := stFloat;
    blr_double: Result := stDouble;
    blr_blob_id, blr_quad: Result := stLong;
    blr_int64:
      case SqlSubType of
        RDB_NUMBERS_NONE:
          { weired bug! We need to check scale too!
            see: http://sourceforge.net/p/zeoslib/tickets/106/ }
          if Scale = 0 then
            Result := stLong
          else
            Result := stBigDecimal;
        RDB_NUMBERS_NUMERIC: Result := stDouble;
        RDB_NUMBERS_DECIMAL:
          if Scale = 0 then
            Result := stLong
          else
            Result := stBigDecimal;
      end;
    blr_long:
      case SqlSubType of
        RDB_NUMBERS_NONE: Result := stInteger;
        RDB_NUMBERS_NUMERIC: Result := stDouble;
        RDB_NUMBERS_DECIMAL:
          if Scale = 0 then
            Result := stInteger
          else
            Result := stBigDecimal;
      end;
    blr_short:
      case SqlSubType of
        RDB_NUMBERS_NONE: Result := stSmall;
        RDB_NUMBERS_NUMERIC: Result := stDouble;
        RDB_NUMBERS_DECIMAL: Result := stDouble;
      end;
    blr_sql_date: Result := stDate;
    blr_sql_time: Result := stTime;
    blr_timestamp: Result := stTimestamp;
    blr_blob, blr_blob2:
      case SqlSubType of
        { Blob Subtypes }
        { types less than zero are reserved for customer use }
        isc_blob_untyped: Result := stBinaryStream;

        { internal subtypes }
        isc_blob_text: Result := stAsciiStream;
        isc_blob_blr: Result := stBinaryStream;
        isc_blob_acl: Result := stAsciiStream;
        isc_blob_ranges: Result := stBinaryStream;
        isc_blob_summary: Result := stBinaryStream;
        isc_blob_format: Result := stAsciiStream;
        isc_blob_tra: Result := stAsciiStream;
        isc_blob_extfile: Result := stAsciiStream;
        isc_blob_debug_info: Result := stBinaryStream;
        else //http://sourceforge.net/p/zeoslib/tickets/111/
          Result := stBinaryStream;
      end;
    else
      Result := ZDbcIntfs.stUnknown;
  end;
  if ( CtrlsCPType = cCP_UTF16) then
    case result of
      stString: Result := stUnicodeString;
      stAsciiStream: Result := stUnicodeStream;
    end;
end;

{**
   Return Interbase SqlType by it number
   @param Value the SqlType number
}
function GetNameSqlType(Value: Word): RawByteString;
begin
  case Value of
    SQL_VARYING: Result := 'SQL_VARYING';
    SQL_TEXT: Result := 'SQL_TEXT';
    SQL_DOUBLE: Result := 'SQL_DOUBLE';
    SQL_FLOAT: Result := 'SQL_FLOAT';
    SQL_LONG: Result := 'SQL_LONG';
    SQL_SHORT: Result := 'SQL_SHORT';
    SQL_TIMESTAMP: Result := 'SQL_TIMESTAMP';
    SQL_BLOB: Result := 'SQL_BLOB';
    SQL_D_FLOAT: Result := 'SQL_D_FLOAT';
    SQL_ARRAY: Result := 'SQL_ARRAY';
    SQL_QUAD: Result := 'SQL_QUAD';
    SQL_TYPE_TIME: Result := 'SQL_TYPE_TIME';
    SQL_TYPE_DATE: Result := 'SQL_TYPE_DATE';
    SQL_INT64: Result := 'SQL_INT64';
    SQL_BOOLEAN: Result := 'SQL_BOOLEAN';
    SQL_BOOLEAN_FB: Result := 'SQL_BOOLEAN_FB';
  else
    Result := 'Unknown';
  end
end;

{**
   Convert raw database string to compiler-native string
}
function ConvertConnRawToString(ConSettings: PZConSettings; const Src: RawByteString): string; overload;
begin
  if ConSettings <> nil then
    Result := ConSettings^.ConvFuncs.ZRawToString(Src, ConSettings^.ClientCodePage^.CP, ConSettings^.CTRL_CP)
  else
    Result := string(Src);
end;

{**
   Convert pointer to raw database string to compiler-native string
}
function ConvertConnRawToString(ConSettings: PZConSettings; Buffer: Pointer; BufLen: Integer): string; overload;
var
  RawStr: RawByteString;
begin
  // TODO: having ZPRawToString we could convert the string directly without SetString
  ZSetString(PAnsiChar(Buffer), BufLen, RawStr);
  if ConSettings <> nil then
    Result := ConSettings^.ConvFuncs.ZRawToString(RawStr, ConSettings^.ClientCodePage^.CP, ConSettings^.CTRL_CP)
  else
    Result := string(RawStr);
end;

{**
   Convert zero-terminated raw database string to compiler-native string
}
function ConvertConnRawToString(ConSettings: PZConSettings; Buffer: Pointer): string; overload;
begin
  Result := ConvertConnRawToString(ConSettings, Buffer, StrLen(Buffer));
end;

function ConvertStringToConnRaw(ConSettings: PZConSettings; const Src: string): RawByteString;
begin
  if ConSettings <> nil then
    Result := ConSettings^.ConvFuncs.ZStringToRaw(Src, ConSettings^.CTRL_CP, ConSettings^.ClientCodePage^.CP)
  else
    Result := RawByteString(Src);
end;

{**
  Checks if Interbase status vector indicates successful operation.
  @param StatusVector a status vector

  @return flag of success
}
function StatusSucceeded(const StatusVector: TARRAY_ISC_STATUS): Boolean;
begin
  Result := not ((StatusVector[0] = 1) and (StatusVector[1] > 0));
end;

{**
  Processes Interbase status vector and returns array of status data.
  @param PlainDriver a Interbase Plain drver
  @param StatusVector a status vector. It contain information about error
  @param ConSettings pointer to connection settings containing codepage info

  @return array of TInterbaseStatus records
}
function InterpretInterbaseStatus(const PlainDriver: TZInterbasePlainDriver;
  const StatusVector: TARRAY_ISC_STATUS;
  const ConSettings: PZConSettings) : TZIBStatusVector;
var
  Buffer: array[0..IBBigLocalBufferLength] of AnsiChar;
  PStatusVector: PISC_STATUS;
  StatusIdx: Integer;
  pCurrStatus: PZIBStatus;
begin
  if StatusSucceeded(StatusVector) then Exit;
  Result := nil;
  PStatusVector := @StatusVector; StatusIdx := 0;
  repeat
    SetLength(Result, Length(Result) + 1);
    pCurrStatus := @Result[High(Result)]; // save pointer to avoid multiple High() calls
    // SQL code and status
    pCurrStatus.SQLCode := PlainDriver.isc_sqlcode(PStatusVector);
    PlainDriver.isc_sql_interprete(pCurrStatus.SQLCode, @Buffer, SizeOf(Buffer));
    pCurrStatus.SQLMessage := ConvertConnRawToString(ConSettings, @Buffer);
    // IB data
    pCurrStatus.IBDataType := StatusVector[StatusIdx];
    case StatusVector[StatusIdx] of
      isc_arg_end:  // end of argument list
        Break;
      isc_arg_gds,  // Long int code
      isc_arg_number,
      isc_arg_vms,
      isc_arg_unix,
      isc_arg_domain,
      isc_arg_dos,
      isc_arg_mpexl,
      isc_arg_mpexl_ipc,
      isc_arg_next_mach,
      isc_arg_netware,
      isc_arg_win32:
        begin
          pCurrStatus.IBDataInt := StatusVector[StatusIdx + 1];
          Inc(StatusIdx, 2);
        end;
      isc_arg_string,  // pointer to string
      isc_arg_interpreted,
      isc_arg_sql_state:
        begin
          pCurrStatus.IBDataStr := ConvertConnRawToString(ConSettings, Pointer(StatusVector[StatusIdx + 1]));
          Inc(StatusIdx, 2);
        end;
      isc_arg_cstring: // length and pointer to string
        begin
          pCurrStatus.IBDataStr := ConvertConnRawToString(ConSettings, Pointer(StatusVector[StatusIdx + 2]), StatusVector[StatusIdx + 1]);
          Inc(StatusIdx, 3);
        end;
      isc_arg_warning: // must not happen for error vector
        Break;
      else
        Break;
    end; // case

    // isc_interprete is deprecated so use fb_interpret instead if available
    if Assigned(PlainDriver.fb_interpret) then
      if PlainDriver.fb_interpret(@Buffer, Length(Buffer), @PStatusVector) = 0 then
        Break
      else
    else
    if PlainDriver.isc_interprete(@Buffer, @PStatusVector) = 0 then
      Break;
    pCurrStatus.IBMessage := ConvertConnRawToString(ConSettings, @Buffer);
  until False;
end;

{**
  Checks for possible sql errors.
  @param PlainDriver a Interbase Plain drver
  @param StatusVector a status vector. It contain information about error
  @param Sql a sql query commend

  @Param Integer Return is the ErrorCode that happened - for disconnecting the database
}
procedure CheckInterbase6Error(const PlainDriver: TZInterbasePlainDriver;
  const StatusVector: TARRAY_ISC_STATUS; const ImmediatelyReleasable: IImmediatelyReleasable;
  const LoggingCategory: TZLoggingCategory = lcOther;
  const SQL: RawByteString = '');
var
  ErrorMessage, ErrorSqlMessage, sSQL: string;
  ErrorCode: LongInt;
  i: Integer;
  InterbaseStatusVector: TZIBStatusVector;
  ConSettings: PZConSettings;
begin
  if StatusSucceeded(StatusVector) then Exit;
  ConSettings := ImmediatelyReleasable.GetConSettings;
  InterbaseStatusVector := InterpretInterbaseStatus(PlainDriver, StatusVector, ConSettings);

  ErrorMessage := '';
  for i := Low(InterbaseStatusVector) to High(InterbaseStatusVector) do
    AppendSepString(ErrorMessage, InterbaseStatusVector[i].IBMessage, '; ');

  ErrorCode := InterbaseStatusVector[0].SQLCode;
  ErrorSqlMessage := InterbaseStatusVector[0].SQLMessage;

  sSQL := ConvertConnRawToString(ConSettings, SQL);
  if sSQL <> '' then
    ErrorSqlMessage := ErrorSqlMessage + ' The SQL: '+sSQL+'; ';

  if ErrorMessage <> '' then
  begin
    DriverManager.LogError(LoggingCategory, ConSettings^.Protocol,
      ConvertStringToConnRaw(ConSettings, ErrorMessage), ErrorCode,
      ConvertStringToConnRaw(ConSettings, ErrorSqlMessage));
    if ErrorCode = {isc_network_error..isc_net_write_err,} isc_lost_db_connection then begin
      ImmediatelyReleasable.ReleaseImmediat(ImmediatelyReleasable);
      raise EZSQLConnectionLost.CreateWithCode(ErrorCode,
      Format(SSQLError1, [sSQL]));
    end else raise EZIBSQLException.Create(
      Format(SSQLError1, [ErrorMessage]), InterbaseStatusVector, sSQL);
  end;
end;

{**
   Prepare statement and create statement handle.
   @param PlainDriver a interbase plain driver
   @param Handle a interbase connection handle
   @param TrHandle a transaction handle
   @param Dialect a interbase sql dialect number
   @param Sql a sql query
   @param ConSettings the connection settings
   @param StmtHandle a statement handle
   @return sql statement type
}
function PrepareStatement(const PlainDriver: TZInterbasePlainDriver;
  Handle: PISC_DB_HANDLE; TrHandle: PISC_TR_HANDLE;
  Dialect: Word; const SQL: RawByteString; const ImmediatelyReleasable: IImmediatelyReleasable;
  var StmtHandle: TISC_STMT_HANDLE): TZIbSqlStatementType;
var
  StatusVector: TARRAY_ISC_STATUS;
begin
  { Allocate an sql statement }
  if StmtHandle = 0 then
    if PlainDriver.isc_dsql_allocate_statement(@StatusVector, Handle, @StmtHandle) <> 0 then
      CheckInterbase6Error(PlainDriver, StatusVector, ImmediatelyReleasable, lcOther, SQL);

  { Prepare an sql statement }
  if PlainDriver.isc_dsql_prepare(@StatusVector, TrHandle, @StmtHandle,
      Length(SQL), Pointer(SQL), Dialect, nil) <> 0 then
    CheckInterbase6Error(PlainDriver, StatusVector, ImmediatelyReleasable, lcPrepStmt, SQL); //Check for disconnect AVZ

  { Set Statement Type }
  Result := GetStatementType(PlainDriver, StmtHandle, ImmediatelyReleasable);

  if Result in [stUnknown, stGetSegment, stPutSegment, stStartTrans, stCommit, stRollback] then begin
    FreeStatement(PlainDriver, StmtHandle, DSQL_CLOSE);  //AVZ
    raise EZSQLException.Create(SStatementIsNotAllowed);
  end;
end;

{**
   Describe SQLDA and allocate memory for result values.
   @param PlainDriver a interbase plain driver
   @param Handle a interbase connection handle
   @param Dialect a interbase sql dialect number
   @param Sql a sql query
   @param StmtHandle a statement handle
   @param SqlData a interbase sql result data
}
procedure PrepareResultSqlData(const PlainDriver: TZInterbasePlainDriver;
  const Dialect: Word; const SQL: RawByteString;
  var StmtHandle: TISC_STMT_HANDLE; const SqlData: IZSQLDA;
  const ImmediatelyReleasable: IImmediatelyReleasable);
var
  StatusVector: TARRAY_ISC_STATUS;
begin
  { Initialise ouput param and fields }
  if PlainDriver.isc_dsql_describe(@StatusVector, @StmtHandle, Dialect, SqlData.GetData) <> 0 then
    CheckInterbase6Error(PlainDriver, StatusVector, ImmediatelyReleasable, lcExecute, SQL);

  if SqlData.GetData^.sqld <> SqlData.GetData^.sqln then
  begin
    SqlData.AllocateSQLDA;
    if PlainDriver.isc_dsql_describe(@StatusVector, @StmtHandle, Dialect, SqlData.GetData) <> 0 then
      CheckInterbase6Error(PlainDriver, StatusVector, ImmediatelyReleasable, lcExecute, Sql);
  end;
  SqlData.InitFields(False);
end;

{**
   Return interbase statement type by statement handle
   @param PlainDriver a interbase plain driver
   @param StmtHandle a statement handle
   @return interbase statement type
}
function GetStatementType(const PlainDriver: TZInterbasePlainDriver;
  const StmtHandle: TISC_STMT_HANDLE; const ImmediatelyReleasable: IImmediatelyReleasable): TZIbSqlStatementType;
var
  TypeItem: AnsiChar;
  StatusVector: TARRAY_ISC_STATUS;
  Buffer: array[0..7] of AnsiChar;
begin
  TypeItem := AnsiChar(isc_info_sql_stmt_type);

  { Get information about a prepared DSQL statement. }
  if PlainDriver.isc_dsql_sql_info(@StatusVector, @StmtHandle, 1,
      @TypeItem, SizeOf(Buffer), @Buffer[0]) <> 0 then
    CheckInterbase6Error(PlainDriver, StatusVector, ImmediatelyReleasable);

  if Buffer[0] = AnsiChar(isc_info_sql_stmt_type) then
    Result := TZIbSqlStatementType(ReadInterbase6Number(PlainDriver, Buffer[1]))
  else
    Result := stUnknown;
end;

{**
   Free interbse allocated statement and SQLDA for input and utput parameters
   @param  the interbase plain driver
   @param  the interbse statement handle
}
procedure FreeStatement(const PlainDriver: TZInterbasePlainDriver; StatementHandle: TISC_STMT_HANDLE; Options: Word);
var
  StatusVector: TARRAY_ISC_STATUS;
begin
  if StatementHandle <> 0  then
    PlainDriver.isc_dsql_free_statement(@StatusVector, @StatementHandle, Options);
  //CheckInterbase6Error(PlainDriver, StatusVector); //raises an unwanted exception if Connection was reopened  See: http://sourceforge.net/p/zeoslib/tickets/40/
end;

{**
   Get affected rows.
   <i>Note:<i> it function may call after statement execution
   @param PlainDriver a interbase plain driver
   @param StmtHandle a statement handle
   @param StatementType a statement type
   @return affected rows
}
function GetAffectedRows(const PlainDriver: TZInterbasePlainDriver;
  const StmtHandle: TISC_STMT_HANDLE; const StatementType: TZIbSqlStatementType;
  const ImmediatelyReleasable: IImmediatelyReleasable): integer;
type
  TCountType = (cntSel, cntIns, cntDel, cntUpd);
var
  ReqInfo: AnsiChar;
  Buffer: array[0..IBLocalBufferLength-1] of AnsiChar;
  StatusVector: TARRAY_ISC_STATUS;
  pBuf, pBufStart: PAnsiChar;
  Len, Item, Count: Integer;
  Counts: array[TCountType] of Integer;
begin
  Result := -1;
  ReqInfo := AnsiChar(isc_info_sql_records);

  if PlainDriver.isc_dsql_sql_info(@StatusVector, @StmtHandle, 1,
      @ReqInfo, SizeOf(Buffer), @Buffer[0]) <> 0 then
    CheckInterbase6Error(PlainDriver, StatusVector, ImmediatelyReleasable);

  if Buffer[0] <> AnsiChar(isc_info_sql_records) then
    Exit;

  pBufStart := @Buffer[1];
  pBuf := pBufStart;
  Len := PlainDriver.isc_vax_integer(pBuf, 2) + 2;
  Inc(pBuf, 2);
  if Buffer[Len] <> AnsiChar(isc_info_end) then
    Exit;

  FillChar(Counts{%H-}, SizeOf(Counts), #0);
  while pBuf - pBufStart <= Len do
  begin
    Item := Byte(pBuf^);

    if Item = isc_info_end then
      Break;

    Inc(pBuf);
    Count := ReadInterbase6NumberWithInc(PlainDriver, pBuf);

    case Item of
      isc_info_req_select_count: Counts[cntSel] := Count;
      isc_info_req_insert_count: Counts[cntIns] := Count;
      isc_info_req_update_count: Counts[cntUpd] := Count;
      isc_info_req_delete_count: Counts[cntDel] := Count;
      else
        raise EZSQLException.Create(SInternalError);
    end;
  end;

  { Note: Update statements could have Select counter <> 0 as well }

  case StatementType of
    stSelect,
    stSelectForUpdate: Result := Counts[cntSel];
    stInsert:          Result := Counts[cntIns];
    stUpdate:          Result := Counts[cntUpd];
    stDelete:          Result := Counts[cntDel];
    stExecProc:
      begin
        { Exec proc could have any counter... So search for the first non-zero counter }
        Result := Counts[cntIns];
        if Result > 0 then Exit;
        Result := Counts[cntUpd];
        if Result > 0 then Exit;
        Result := Counts[cntDel];
        if Result > 0 then Exit;
        Result := Counts[cntSel];
      end;
    else
      Result := -1;
  end;
end;

procedure BindSQLDAInParameters(BindList: TZBindList;
  const ParamSqlData: IZParamsSQLDA; const ConSettings: PZConSettings;
  const CodePageArray: TWordDynArray; ArrayOffSet, ArrayItersCount: Integer);
var
  I, J, ParamIndex, CP: Integer;
  TempBlob: IZBlob;
  Buffer: Pointer;
  Len: Integer;
  RawTemp: RawByteString;
  UniTemp: ZWideString;
  IsNull: Boolean;

  { array DML bindings }
  ZData: Pointer; //array entry
begin
  ParamIndex := 0;
  for J := ArrayOffSet to ArrayOffSet+ArrayItersCount-1 do
    for i := 0 to BindList.Count -1 do
    begin
      IsNull := IsNullFromArray(BindList[i].Value, J);
      ZData := PZArray(BindList[i].Value).VArray;
      if (ZData = nil) or (IsNull) then
        ParamSqlData.UpdateNull(ParamIndex, True)
      else
        case TZSQLType(PZArray(BindList[i].Value).VArrayType) of
          stBoolean: ParamSqlData.UpdateBoolean(ParamIndex, TBooleanDynArray(ZData)[J]);
          stByte: ParamSqlData.UpdateSmall(ParamIndex, TByteDynArray(ZData)[J]);
          stShort: ParamSqlData.UpdateSmall(ParamIndex, TShortIntDynArray(ZData)[J]);
          stWord: ParamSqlData.UpdateInt(ParamIndex, TWordDynArray(ZData)[J]);
          stSmall: ParamSqlData.UpdateSmall(ParamIndex, TSmallIntDynArray(ZData)[J]);
          stLongWord: ParamSqlData.UpdateLong(ParamIndex, TLongWordDynArray(ZData)[J]);
          stInteger: ParamSqlData.UpdateInt(ParamIndex, TIntegerDynArray(ZData)[J]);
          stLong: ParamSqlData.UpdateLong(ParamIndex, TInt64DynArray(ZData)[J]);
          stULong: ParamSqlData.UpdateLong(ParamIndex, TUInt64DynArray(ZData)[J]);
          stFloat: ParamSqlData.UpdateFloat(ParamIndex, TSingleDynArray(ZData)[J]);
          stDouble: ParamSqlData.UpdateDouble(ParamIndex, TDoubleDynArray(ZData)[J]);
          stCurrency: ParamSqlData.UpdateBigDecimal(ParamIndex, TCurrencyDynArray(ZData)[J]);
          stBigDecimal: ParamSqlData.UpdateBigDecimal(ParamIndex, TExtendedDynArray(ZData)[J]);
          stGUID: if  ParamSqlData.GetIbSqlType(ParamIndex) = CS_BINARY then
                    ParamSqlData.UpdatePAnsiChar(ParamIndex, @TGUIDDynArray(ZData)[j].D1, SizeOf(TGUID))
                  else begin
                    RawTemp := GUIDToRaw(TGUIDDynArray(ZData)[j]);
                    ParamSqlData.UpdatePAnsiChar(ParamIndex, Pointer(RawTemp), Length(RawTemp));
                  end;
          stString, stUnicodeString:
            begin
              CP := ParamSqlData.GetIbSqlSubType(ParamIndex);  //get code page
              if CP <> CS_BINARY then begin
                if (CP > High(CodePageArray)) or (CP = CS_NONE)
                then CP := ConSettings^.ClientCodePage^.CP
                else CP := CodePageArray[CP];
                case PZArray(BindList[i].Value).VArrayVariantType of
                  vtString: RawTemp := ConSettings.ConvFuncs.ZStringToRaw(TStringDynArray(ZData)[j], ConSettings.CTRL_CP, CP);
                  {$IFNDEF NO_ANSISTRING}
                  vtAnsiString: RawTemp := Consettings^.ConvFuncs.ZAnsiToRaw(TAnsiStringDynArray(ZData)[j], CP);
                  {$ENDIF}
                  {$IFNDEF NO_UTF8STRING}
                  vtUTF8String: if ZCompatibleCodePages(CP, zCP_UTF8) then begin
                        ParamSqlData.UpdatePAnsiChar(ParamIndex, Pointer(TUTF8StringDynArray(ZData)[j]), Length(TUTF8StringDynArray(ZData)[j]));
                        Inc(ParamIndex);
                        continue;
                      end else
                        RawTemp := Consettings^.ConvFuncs.ZUTF8ToRaw(TUTF8StringDynArray(ZData)[j], CP);
                  {$ENDIF}
                  vtRawByteString: RawTemp := TRawByteStringDynArray(ZData)[j];
                  vtUnicodeString: RawTemp := ZUnicodeToRaw(TUnicodeStringDynArray(ZData)[j], CP);
                  vtCharRec: if ZCompatibleCodePages(TZCharRecDynArray(ZData)[j].CP, cp) or (TZCharRecDynArray(ZData)[j].Len = 0) then begin
                        ParamSqlData.UpdatePAnsiChar(ParamIndex, TZCharRecDynArray(ZData)[j].P, TZCharRecDynArray(ZData)[j].Len);
                        Inc(ParamIndex);
                        continue;
                      end else if ZCompatibleCodePages(TZCharRecDynArray(ZData)[j].CP, zCP_UTF16) then
                        RawTemp := PUnicodeToRaw(TZCharRecDynArray(ZData)[j].P, TZCharRecDynArray(ZData)[j].Len, CP)
                      else begin
                        UniTemp := PRawToUnicode(TZCharRecDynArray(ZData)[j].P, TZCharRecDynArray(ZData)[j].Len, TZCharRecDynArray(ZData)[j].CP);
                        RawTemp := ZUnicodeToRaw(UniTemp, CP)
                      end;
                  else
                    raise Exception.Create('Unsupported String Variant');
                end;
                ParamSqlData.UpdatePAnsiChar(ParamIndex, Pointer(RawTemp), Length(RawTemp));
              end else case PZArray(BindList[i].Value).VArrayVariantType of
                {$IFNDEF UNICODE}vtString,{$ENDIF}
                {$IFNDEF NO_ANSISTRING}vtAnsiString, {$ENDIF}
                {$IFNDEF NO_UTF8STRING}vtUTF8String, {$ENDIF}
                vtRawByteString:
                    ParamSqlData.UpdatePAnsiChar(ParamIndex, Pointer(TRawByteStringDynArray(ZData)[j]), Length(TRawByteStringDynArray(ZData)[j]));
                vtUnicodeString{$IFDEF UNICODE}, vtString{$ENDIF}:
                  raise Exception.Create('Unsupported String Variant');
                vtCharRec: if not ZCompatibleCodePages(TZCharRecDynArray(ZData)[j].CP, zCP_UTF16) or (TZCharRecDynArray(ZData)[j].Len = 0)
                    then ParamSqlData.UpdatePAnsiChar(ParamIndex, TZCharRecDynArray(ZData)[j].P, TZCharRecDynArray(ZData)[j].Len)
                    else raise Exception.Create('Unsupported String Variant');
                else
                  raise Exception.Create('Unsupported String Variant');
              end;
            end;
          stBytes:
            ParamSqlData.UpdateBytes(ParamIndex, TBytesDynArray(ZData)[j]);
          stDate:
            ParamSqlData.UpdateDate(ParamIndex, TDateTimeDynArray(ZData)[j]);
          stTime:
            ParamSqlData.UpdateTime(ParamIndex, TDateTimeDynArray(ZData)[j]);
          stTimestamp:
            ParamSqlData.UpdateTimestamp(ParamIndex, TDateTimeDynArray(ZData)[j]);
          stAsciiStream,
          stUnicodeStream,
          stBinaryStream:
            begin
              TempBlob := TInterfaceDynArray(ZData)[j] as IZBlob;
              if not TempBlob.IsEmpty then begin
                if (ParamSqlData.GetFieldSqlType(ParamIndex) in [stUnicodeStream, stAsciiStream] ) then
                  if TempBlob.IsClob then begin
                    Buffer := TempBlob.GetPAnsiChar(ConSettings^.ClientCodePage^.CP);
                    Len := TempBlob.Length;
                  end else begin
                    RawTemp := GetValidatedAnsiStringFromBuffer(TempBlob.GetBuffer, TempBlob.Length, ConSettings);
                    Len := Length(RawTemp);
                    if Len = 0 then
                      Buffer := PEmptyAnsiString
                    else
                      Buffer := Pointer(RawTemp);
                  end
                else begin
                  Buffer := TempBlob.GetBuffer;
                  Len := TempBlob.Length;
                end;
                if Buffer <> nil then
                  ParamSqlData.WriteLobBuffer(ParamIndex, Buffer, Len);
              end;
            end
          else
            raise EZIBConvertError.Create(SUnsupportedParameterType);
        end;
      Inc(ParamIndex);
    end;
end;
{**
   Read blob information by it handle such as blob segment size, segments count,
   blob size and type.
   @param PlainDriver
   @param BlobInfo the blob information structure
}
procedure GetBlobInfo(const PlainDriver: TZInterbasePlainDriver;
  const BlobHandle: TISC_BLOB_HANDLE; out BlobInfo: TIbBlobInfo;
  const ImmediatelyReleasable: IImmediatelyReleasable);
var
  Items: array[0..3] of AnsiChar;
  Results: array[0..99] of AnsiChar;
  pBuf, pBufStart: PAnsiChar;
  Item, ItemVal: Integer;
  StatusVector: TARRAY_ISC_STATUS;
begin
  Items[0] := AnsiChar(isc_info_blob_num_segments);
  Items[1] := AnsiChar(isc_info_blob_max_segment);
  Items[2] := AnsiChar(isc_info_blob_total_length);
  Items[3] := AnsiChar(isc_info_blob_type);

  if PlainDriver.isc_blob_info(@StatusVector, @BlobHandle, 4, @items[0],
      SizeOf(Results), @Results[0]) <> 0 then
    CheckInterbase6Error(PlainDriver, StatusVector, ImmediatelyReleasable);

  FillChar(BlobInfo{%H-}, SizeOf(BlobInfo), #0);

  pBufStart := @Results[0];
  pBuf := pBufStart;
  while pBuf - pBufStart <= SizeOf(Results) do
  begin
    Item := Byte(pBuf^);
    if Item = isc_info_end then
      Break;

    Inc(pBuf);
    ItemVal := ReadInterbase6NumberWithInc(PlainDriver, pBuf);

    case Item of
      isc_info_blob_num_segments:
        BlobInfo.NumSegments := ItemVal;
      isc_info_blob_max_segment:
        BlobInfo.MaxSegmentSize := ItemVal;
      isc_info_blob_total_length:
        BlobInfo.TotalSize := ItemVal;
      isc_info_blob_type:
        BlobInfo.BlobType := ItemVal;
    end;
  end;
end;

{**
   Read blob field data to stream by it ISC_QUAD value
   Note: DefaultBlobSegmentSize constant used for limit segment size reading
   @param Handle the database connection handle
   @param TransactionHandle the transaction handle
   @param BlobId the ISC_QUAD structure
   @param Size the result buffer size
   @param Buffer the pointer to result buffer

   Note: Buffer must be nill. Function self allocate memory for data
    and return it size
}
procedure ReadBlobBufer(const PlainDriver: TZInterbasePlainDriver;
  const Handle: PISC_DB_HANDLE; const TransactionHandle: PISC_TR_HANDLE;
  const BlobId: TISC_QUAD; out Size: Integer; out Buffer: Pointer;
  const Binary: Boolean; const ImmediatelyReleasable: IImmediatelyReleasable);
var
  TempBuffer: PAnsiChar;
  BlobInfo: TIbBlobInfo;
  CurPos: LongInt;
  BytesRead, SegLen: ISC_USHORT;
  BlobHandle: TISC_BLOB_HANDLE;
  StatusVector: TARRAY_ISC_STATUS;
begin
  BlobHandle := 0;
  CurPos := 0;
//  SegmentLenght := UShort(DefaultBlobSegmentSize);

  { open blob }
  if PlainDriver.isc_open_blob2(@StatusVector, Handle,
         TransactionHandle, @BlobHandle, @BlobId, 0 , nil) <> 0 then
    CheckInterbase6Error(PlainDriver, StatusVector, ImmediatelyReleasable);

  { get blob info }
  GetBlobInfo(PlainDriver, BlobHandle, BlobInfo, ImmediatelyReleasable);
  Size := BlobInfo.TotalSize;
  SegLen := BlobInfo.MaxSegmentSize;

  { Allocates a blob buffer }
  Buffer := AllocMem(BlobInfo.TotalSize+Ord(not Binary)); //left space for leading #0 terminator

  TempBuffer := Buffer;

  { Copies data to blob buffer }
  while CurPos < BlobInfo.TotalSize do begin
    if (CurPos + SegLen > BlobInfo.TotalSize) then
      SegLen := BlobInfo.TotalSize - CurPos;
    if not(PlainDriver.isc_get_segment(@StatusVector, @BlobHandle,
           @BytesRead, SegLen, TempBuffer) = 0) or
          (StatusVector[1] <> isc_segment) then
      CheckInterbase6Error(PlainDriver, StatusVector, ImmediatelyReleasable);
    Inc(CurPos, BytesRead);
    Inc(TempBuffer, BytesRead);
  end;
  if not Binary then
    PByte(PAnsiChar(Buffer)+Size)^ := Ord(#0);

  { close blob handle }
  if PlainDriver.isc_close_blob(@StatusVector, @BlobHandle) <> 0 then
    CheckInterbase6Error(PlainDriver, StatusVector, ImmediatelyReleasable);
end;

{**
   Return interbase server version string
   @param PlainDriver a interbase plain driver
   @param Handle the database connection handle
   @param isc_info a ISC_INFO_XXX number
   @param ConSettings then PZConSettings of active connection
   @return ISC_INFO string
}
function GetDBStringInfo(const PlainDriver: TZInterbasePlainDriver;
  Handle: PISC_DB_HANDLE; isc_info: Byte; const ImmediatelyReleasable: IImmediatelyReleasable): String;
var
  StatusVector: TARRAY_ISC_STATUS;
  Buffer: array[0..IBBigLocalBufferLength - 1] of AnsiChar;
begin
  if PlainDriver.isc_database_info(@StatusVector, Handle, 1, @isc_info,
      SizeOf(Buffer), @Buffer[0]) <> 0 then
    CheckInterbase6Error(PlainDriver, StatusVector, ImmediatelyReleasable);

  { Buffer:
      0     - type of info
      1..2  - total data length
      3     - #1
      4     - string length
      5..N  - string
      N+1   - #1 }
  if Buffer[0] = AnsiChar(isc_info) then
    Result := ConvertConnRawToString(ImmediatelyReleasable.GetConSettings, @Buffer[5], Integer(Buffer[4]))
  else
    Result := '';
end;

{**
   Return interbase server version string
   @param PlainDriver a interbase plain driver
   @param Handle the database connection handle
   @param isc_info a ISC_INFO_XXX number
   @param ConSettings then PZConSettings of active connection
   @return ISC_INFO Integer
}
function GetDBIntegerInfo(const PlainDriver: TZInterbasePlainDriver;
  Handle: PISC_DB_HANDLE; isc_info: Byte; const ImmediatelyReleasable: IImmediatelyReleasable): LongInt;
var
  StatusVector: TARRAY_ISC_STATUS;
  Buffer: array[0..31] of AnsiChar; // this should be enough for any number
begin
  if PlainDriver.isc_database_info(@StatusVector, Handle, 1, @isc_info,
      SizeOf(Buffer), @Buffer[0]) <> 0 then
    CheckInterbase6Error(PlainDriver, StatusVector, ImmediatelyReleasable);

  { Buffer:
      0     - type of info
      1..2  - number length
      3..N  - number
      N+1   - #1 }
  if Buffer[0] = AnsiChar(isc_info)
    then Result := ReadInterbase6Number(PlainDriver, Buffer[1])
    else Result := -1;
end;

{**
   Return interbase database dialect
   @param PlainDriver a interbase plain driver
   @param Handle the database connection handle
   @return interbase database dialect
}
function GetDBSQLDialect(const PlainDriver: TZInterbasePlainDriver;
  const Handle: PISC_DB_HANDLE; const ImmediatelyReleasable: IImmediatelyReleasable): Integer;
begin
  Result := GetDBIntegerInfo(PlainDriver, Handle, isc_info_db_SQL_Dialect, ImmediatelyReleasable);
  if Result = -1 then
    Result := SQL_DIALECT_V5;
end;

{ TZFBSpecificData }

function TZIBSpecificData.Clone: TZExceptionSpecificData;
begin
  Result := TZIBSpecificData.Create;
  TZIBSpecificData(Result).FStatusVector := StatusVector;
  TZIBSpecificData(Result).FSQL := SQL;
  TZIBSpecificData(Result).FIBErrorCode := IBErrorCode;
  TZIBSpecificData(Result).FIBStatusCode := IBStatusCode;
end;

{ EZIBSQLException }

constructor EZIBSQLException.Create(const Msg: string; const StatusVector: TZIBStatusVector; const SQL: string);
var
  i, SQLErrCode, IBErrorCode: Integer;
  IBStatusCode: String;
begin
  SQLErrCode := 0; IBErrorCode := 0;
  // find main IB code
  for i := Low(StatusVector) to High(StatusVector) do
    if StatusVector[i].IBDataType = isc_arg_gds then
    begin
      IBErrorCode := StatusVector[i].IBDataInt;
      IBStatusCode := StatusVector[i].IBMessage;
      SQLErrCode := StatusVector[i].SQLCode;
      Break;
    end;

  inherited CreateWithCode(SQLErrCode, Msg);
  FSpecificData := TZIBSpecificData.Create;
  TZIBSpecificData(FSpecificData).FStatusVector := StatusVector;
  TZIBSpecificData(FSpecificData).FSQL := SQL;
  TZIBSpecificData(FSpecificData).FIBErrorCode := IBErrorCode;
  TZIBSpecificData(FSpecificData).FIBStatusCode := IBStatusCode;
end;

{ TSQLDA }
constructor TZSQLDA.Create(const Connection: IZConnection);
begin
  FConnection := Connection;
  Self.ConSettings := Connection.GetConSettings;
  FPlainDriver := TZInterbasePlainDriver(Connection.GetIZPlainDriver.GetInstance);

  GetMem(FXSQLDA, XSQLDA_LENGTH(0));
  FillChar(FXSQLDA^, XSQLDA_LENGTH(0), {$IFDEF Use_FastCodeFillChar}#0{$ELSE}0{$ENDIF});
  FXSQLDA.sqln := 0;
  FXSQLDA.sqld := 0;

  FXSQLDA.version := SQLDA_VERSION1;
end;

{**
   Free allocated memory and free object
}
destructor TZSQLDA.Destroy;
begin
  FreeParamtersValues;
  FreeMem(FXSQLDA);
  inherited Destroy;
end;
{**
   Allocate memory for SQLVar in SQLDA structure for every
   fields by it length.
}
procedure TZSQLDA.InitFields(Parameters: boolean);
var
  I: Integer;
  SqlVar: PXSQLVAR;
begin
  {$R-}
  for I := 0 to FXSQLDA.sqld - 1 do begin
    SqlVar := @FXSQLDA.SqlVar[I];
    FDecribedLengthArray[i] := SqlVar.sqllen;
    FDecribedScaleArray[i] := SqlVar.sqlscale;
    FDecribedTypeArray[i] := SqlVar.sqltype;
    ReallocMem(SqlVar.sqldata, Max(1, SqlVar.sqllen+(2*Ord(SqlVar.sqltype and (not 1) = SQL_VARYING))));
    if Parameters then begin
      //This code used when allocated sqlind parameter for Param SQLDA
      SqlVar.sqltype := SqlVar.sqltype or 1;
      IbReAlloc(SqlVar.sqlind, 0, SizeOf(Short))
    end else
      //This code used when allocated sqlind parameter for Result SQLDA
      if (SqlVar.sqltype and 1) <> 0
      then ReallocMem(SqlVar.sqlind, SizeOf(Short))
      else SqlVar.sqlind := nil;
  end;
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
end;

{**
   Clear allocated data for SQLDA paramters
}
procedure TZSQLDA.FreeParamtersValues;
var
  I: Integer;
  SqlVar: PXSQLVAR;
begin
  {$R-}
  for I := 0 to FXSQLDA.sqln - 1 do
  begin
    SqlVar := @FXSQLDA.SqlVar[I];
    FreeMem(SqlVar.sqldata);
    FreeMem(SqlVar.sqlind);
    SqlVar.sqldata := nil;
    SqlVar.sqlind := nil;
  end;
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
end;

{**
   Chech reange count fields. If index out of range raised exception.
   @param Index the index field
}
procedure TZSQLDA.CheckRange(const Index: Word);
begin
  Assert(Index < Word(FXSQLDA.sqln), 'Out of Range.');
end;

function ConvertConnRawToStringWithOpt(ConSettings: PZConSettings; Buffer: Pointer; BufLen: Integer): string;
begin
  {$IFDEF UNICODE}
  Result := PRawToUnicode(Buffer, BufLen, ConSettings^.ClientCodePage^.CP);
  {$ELSE}
    if (not ConSettings^.AutoEncode) or ZCompatibleCodePages(ConSettings^.ClientCodePage^.CP, ConSettings^.CTRL_CP) then
      SetString(Result, PChar(Buffer), BufLen)
    else
      Result := ZUnicodeToString(PRawToUnicode(Buffer, BufLen, ConSettings^.ClientCodePage^.CP), ConSettings^.CTRL_CP);
  {$ENDIF}
end;

{**
   Return alias name for field
   @param Index the index fields
   @return the alias name
}
function TZSQLDA.GetFieldAliasName(const Index: Word): String;
begin
  CheckRange(Index);
  {$R-}
  Result := ConvertConnRawToStringWithOpt(ConSettings,
    @FXSQLDA.sqlvar[Index].aliasname[0], FXSQLDA.sqlvar[Index].aliasname_length);
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
end;

{**
   Return pointer to SQLDA structure
}
function TZSQLDA.GetData: PXSQLDA;
begin
  result := FXSQLDA;
end;

{**
   Get fields count not allocated.
   @return fields count
}
function TZSQLDA.GetFieldCount: Integer;
begin
  Result := FXSQLDA.sqld;
end;

{**
   Return field index by it name
   @param Index the index fields
   @return the index field
}
function TZSQLDA.GetFieldIndex(const Name: String): Word;
var S: String;
  P1, P2: PChar;
begin
  {$R-}
  for Result := 0 to GetFieldCount - 1 do
  begin
    S := ConvertConnRawToString(ConSettings, @FXSQLDA.sqlvar[Result].aliasname[0], FXSQLDA.sqlvar[Result].aliasname_length);
    if Length(S) = Length(name) then
    begin
      P1 := Pointer(Name);
      P2 := Pointer(S);
      if StrLIComp(P1, P2, Length(S)) = 0 then
        Exit;
    end;
  end;
  raise Exception.Create(Format(SFieldNotFound1, [name]));
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
end;

{**
   Return field length
   @param Index the index fields
   @return the field lenth
}
function TZSQLDA.GetFieldLength(const Index: Word): SmallInt;
begin
  Result := GetIbSqlLen(Index);
end;

{**
   Return field scale
   @param Index the index fields
   @return the field scale
}
function TZSQLDA.GetFieldScale(const Index: Word): integer;
begin
  CheckRange(Index);
  {$R-}
  Result := Abs(FXSQLDA.sqlvar[Index].sqlscale);
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
end;

{**
   Convert Interbase sql type to SQLType
   @param Index the index fields
   @return the SQLType
}
function TZSQLDA.GetFieldSqlType(const Index: Word): TZSQLType;
var
  SqlScale: Integer;
  SqlSubType: Integer;
begin
  SqlScale := GetFieldScale(Index);
  SqlSubType := GetIbSqlSubType(Index);

  case GetIbSqlType(Index) of
    SQL_VARYING, SQL_TEXT:
      case SqlSubType of
        1: {Octets} Result := stBytes;
        else
          Result := stString;
      end;
    SQL_LONG:
      begin
        if SqlScale = 0 then
          Result := stInteger
        else
          Result := stDouble;
      end;
    SQL_SHORT:
      begin
        if SqlScale = 0 then
          Result := stSmall
        else
          Result := stFloat; //Numeric with low precision
       end;
    SQL_FLOAT:
      Result := stFloat;
    SQL_DOUBLE, SQL_D_FLOAT:
      Result := stDouble;
    SQL_BOOLEAN, SQL_BOOLEAN_FB:
      Result := stBoolean;
    SQL_DATE: Result := stTimestamp;
    SQL_TYPE_TIME: Result := stTime;
    SQL_TYPE_DATE: Result := stDate;
    SQL_INT64:
      begin
        if SqlScale = 0 then
          Result := stLong
        else
          Result := stBigDecimal;
      end;
    SQL_QUAD, SQL_BLOB:
      begin
        if SqlSubType = isc_blob_text then
          Result := stAsciiStream
        else
          Result := stBinaryStream;
      end;
    SQL_ARRAY: Result := stArray;
  else
      Result := stString;
  end;
  if ( ConSettings.CPType = cCP_UTF16 ) then
    case result of
      stString: Result := stUnicodeString;
      stAsciiStream: Result := stUnicodeStream;
    end;
end;

{**
   Return own name for field
   @param Index the index fields
   @return the own name
}
function TZSQLDA.GetFieldOwnerName(const Index: Word): String;
begin
  CheckRange(Index);
  {$R-}
  Result := ConvertConnRawToStringWithOpt(ConSettings,
    @FXSQLDA.sqlvar[Index].OwnName[0], FXSQLDA.sqlvar[Index].OwnName_length);
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
end;

{**
   Return real name for field
   @param Index the index fields
   @return the real name
}
function TZSQLDA.GetFieldRelationName(const Index: Word): String;
begin
  CheckRange(Index);
  {$R-}
  Result := ConvertConnRawToStringWithOpt(ConSettings,
    @FXSQLDA.sqlvar[Index].RelName[0], FXSQLDA.sqlvar[Index].RelName_length);
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
end;

{**
   Get Interbase sql fields lenth
   @param Index the index fields
   @return Interbase sql fields lenth
}
function TZSQLDA.GetIbSqlLen(const Index: Word): Smallint;
begin
  CheckRange(Index);
  {$R-}
  Result := FXSQLDA.sqlvar[Index].sqllen;
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
end;

{**
   Return sql name for field
   @param Index the index fields
   @return the sql name
}
function TZSQLDA.GetFieldSqlName(const Index: Word): String;
begin
  CheckRange(Index);
  {$R-}
  Result := ConvertConnRawToStringWithOpt(ConSettings,
    @FXSQLDA.sqlvar[Index].sqlname[0], FXSQLDA.sqlvar[Index].sqlname_length);
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
end;

{**
   Get Interbase subsql type
   @param Index the index fields
   @return the Interbase subsql
}
function TZSQLDA.GetIbSqlSubType(const Index: Word): Smallint;
begin
  CheckRange(Index);
  {$R-}
  Result := FXSQLDA.sqlvar[Index].sqlsubtype;
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
end;

{**
   Get Interbase sql type
   @param Index the index fields
   @return the interbase sql type
}
function TZSQLDA.GetIbSqlType(const Index: Word): Smallint;
begin
  CheckRange(Index);
  {$R-}
  Result := FXSQLDA.sqlvar[Index].sqltype and not (1);
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
end;

{**
   Reallocate memory and fill memory by #0
   @param pointer to memory block
   @param old size of memory block
   @param new size of memory block
}
procedure TZSQLDA.IbReAlloc(var P; OldSize, NewSize: Integer);
begin
  ReallocMem(Pointer(P), NewSize);
  if NewSize > OldSize then
    Fillchar((PAnsiChar(P) + OldSize)^, NewSize - OldSize, #0);
end;

procedure TZSQLDA.SetFieldType(const Index: Word; Size: Integer; Code: Smallint;
  Scale: Smallint);
begin
  CheckRange(Index);
  {$R-}
  with FXSQLDA.sqlvar[Index] do
  begin
    sqltype := Code;
    if Scale <= 0 then
      sqlscale := Scale;
    sqllen := Size;
    if (Size > 0) then begin
      IbReAlloc(sqldata, 0, Size);
    end else begin
      FreeMem(sqldata);
      sqldata := nil;
    end;
  end;
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
end;

{**
   Indicate blob field
   @param Index the index fields
   @return true if blob field overwise false
}
function TZSQLDA.IsBlob(const Index: Word): boolean;
begin
  CheckRange(Index);
  {$R-}
  Result := ((FXSQLDA.sqlvar[Index].sqltype and not(1)) = SQL_BLOB);
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
end;

{**
   Indicate blob field
   @param Index the index fields
   @return true if field nullable overwise false
}
function TZSQLDA.IsNullable(const Index: Word): boolean;
begin
  CheckRange(Index);
  {$R-}
  Result := FXSQLDA.sqlvar[Index].sqltype and 1 = 1
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
end;

procedure TZSQLDA.ReleaseImmediat(const Sender: IImmediatelyReleasable);
begin
  if Sender <> (FConnection as IImmediatelyReleasable) then
    (FConnection as IImmediatelyReleasable).ReleaseImmediat(Sender);
end;

{**
   Reallocate SQLDA to fields count length
   @param Value the count fields
}
procedure TZSQLDA.AllocateSQLDA;
begin
  IbReAlloc(FXSQLDA, XSQLDA_LENGTH(FXSQLDA.sqln), XSQLDA_LENGTH(FXSQLDA.sqld));
  FXSQLDA.sqln := FXSQLDA.sqld;
  SetLength(FDecribedLengthArray, FXSQLDA.sqld);
  SetLength(FDecribedScaleArray, FXSQLDA.sqld);
  SetLength(FDecribedTypeArray, FXSQLDA.sqld);
end;

{ TParamsSQLDA }

{**
   Encode pascal string to Interbase paramter buffer
   @param Code the Interbase data type
   @param Index the index target filed
   @param Str the source string
}

procedure TZParamsSQLDA.EncodeString(const Code: Smallint; const Index: Word;
  const Str: RawByteString);
begin
  if Pointer(Str) = nil then //let's avoid RTL conversion!
    EncodePData(Code, Index, Pointer(PEmptyAnsiString), 0)
  else
    EncodePData(Code, Index, Pointer(Str),
      {$IFDEF WITH_TBYTES_AS_RAWBYTESTRING}
      Length(Str)-1
      {$ELSE}
      {%H-}PLengthInt(NativeUInt(Str) - StringLenOffSet)^
      {$ENDIF});
end;

function TZParamsSQLDA.GetAsLogValue(Index: Word): RawByteString;
var
  SQLCode: SmallInt;
  TempDate: TCTimeStructure;
  DT, DT2: TDateTime;
begin
  {$R-}
  with FXSQLDA.sqlvar[Index] do begin
    if (sqlind <> nil) and (sqlind^ = -1) then
      Result := 'null'
    else begin
      SQLCode := (sqltype and not(1));
      if (sqlscale < 0)  then
        case SQLCode of
          SQL_SHORT  : Result := FloatToRaw(PSmallInt(sqldata)^ / IBScaleDivisor[sqlscale]);
          SQL_LONG   : Result := FloatToRaw(PInteger(sqldata)^  / IBScaleDivisor[sqlscale]);
          SQL_INT64,
          SQL_QUAD   : Result := FloatToRaw(PInt64(sqldata)^    / IBScaleDivisor[sqlscale]);
          SQL_DOUBLE : Result := FloatToRaw(PDouble(sqldata)^);
        else
          raise EZIBConvertError.Create(Format(SErrorConvertionField,
            ['parameter', GetNameSqlType(SQLCode)]));
        end
      else case SQLCode of
        SQL_DOUBLE    : Result := FloatToRaw(PDouble(sqldata)^);
        SQL_LONG      : Result := IntToRaw(PInteger(sqldata)^);
        SQL_D_FLOAT,
        SQL_FLOAT     : Result := FloatToRaw(PSingle(sqldata)^);
        SQL_BOOLEAN   : Result := BoolToRawEx(PSmallint(sqldata)^ <> 0);
        SQL_BOOLEAN_FB: Result := BoolToRawEx(PByte(sqldata)^ <> 0);
        SQL_SHORT     : Result := IntToRaw(PSmallint(sqldata)^);
        SQL_INT64     : Result := IntToRaw(PInt64(sqldata)^);
        SQL_TEXT      : ZSetString(sqldata, sqllen, Result);
        SQL_VARYING   : ZSetString(PAnsiChar(@PISC_VARYING(sqldata).str[0]), PISC_VARYING(sqldata).strlen, Result);
        SQL_BLOB      : Result := '(LOB)';
        SQL_TYPE_TIME : begin
                          FPlainDriver.isc_decode_sql_time(PISC_TIME(sqldata), @TempDate);
                          if TryEncodeTime(Word(TempDate.tm_hour), Word(TempDate.tm_min),
                              Word(TempDate.tm_sec),  Word((PISC_TIME(sqldata)^ mod ISC_TIME_SECONDS_PRECISION) div 10), DT) then
                            Result := ZSysUtils.DateTimeToRawSQLTime(Dt, ConSettings.WriteFormatSettings, True)
                          else Result := '(time)';
                        end;
        SQL_TYPE_DATE : begin
                          FPlainDriver.isc_decode_sql_date(PISC_DATE(sqldata), @TempDate);
                          if TryEncodeDate(Word(TempDate.tm_year+1900), Word(TempDate.tm_mon+1),
                              Word(TempDate.tm_mday), DT2) then
                            Result := ZSysUtils.DateTimeToRawSQLDate(DT2, ConSettings.WriteFormatSettings, True)
                          else Result := '(date)';
                        end;
        SQL_TIMESTAMP : begin
                          FPlainDriver.isc_decode_timestamp(PISC_TIMESTAMP(sqldata), @TempDate);
                          if not TryEncodeTime(Word(TempDate.tm_hour), Word(TempDate.tm_min),
                              Word(TempDate.tm_sec),  Word((PISC_TIME(sqldata)^ mod ISC_TIME_SECONDS_PRECISION) div 10), DT) then
                            DT := 0;
                          if not TryEncodeDate(Word(TempDate.tm_year+1900), Word(TempDate.tm_mon+1),
                              Word(TempDate.tm_mday), DT2) then
                            DT2 := 0;
                          Result := ZSysUtils.DateTimeToRawSQLTimeStamp(DT+DT2, ConSettings.WriteFormatSettings, True)
                        end;
      else
        raise EZIBConvertError.Create(Format(SErrorConvertionField,
          ['parameter', GetNameSqlType(SQLCode)]));
      end;
    end;
  end;
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
end;

procedure TZParamsSQLDA.EncodePData(Code: Smallint; Index: Word;
  Value: PAnsiChar; Len: LengthInt);
begin
  {$R-}
  //EH: Hint it seems we don't need a #0 term here, sqlen is the indicator
   with FXSQLDA.sqlvar[Index] do
    case Code of
      SQL_TEXT:
        begin
          if Len > FDecribedLengthArray[Index] then
            raise EZSQLException.Create(Format(SParamValueExceeded, [Index]));
            //ReallocMem(sqldata, Len);
          {$IFDEF FAST_MOVE}ZFastCode{$ELSE}System{$ENDIF}.Move(Value^, sqldata^, len);
          sqllen := len;
        end;
      SQL_VARYING:
        begin
          if Len > FDecribedLengthArray[Index] then
            //raise EZSQLException.Create(SPattern2Long);
            ReallocMem(sqldata, Len+SizeOf(Short));
          PISC_VARYING(sqldata).strlen := Len;
          {$IFDEF FAST_MOVE}ZFastCode{$ELSE}System{$ENDIF}.Move(Value^, PISC_VARYING(sqldata).str, Len);
          sqllen := Len+SizeOf(Short);
        end;
    end;
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
end;

{**
   Set up parameter BigDecimal value
   @param Index the target parameter index
   @param Value the source value
}
procedure TZParamsSQLDA.UpdateBigDecimal(const Index: Integer; const Value: Extended);
var
  SQLCode: SmallInt;
begin
  CheckRange(Index);

  {$R-}
  with FXSQLDA.sqlvar[Index] do
  begin
    if not FDecribedTypeArray[Index] = sqltype then
      SetFieldType(Index, FDecribedLengthArray[Index], FDecribedTypeArray[Index], FDecribedScaleArray[Index]);

    SQLCode := (sqltype and not(1));

    if (sqlscale < 0)  then //http://code.google.com/p/fbclient/wiki/DatatypeMapping
      case SQLCode of
        SQL_SHORT  : PSmallInt(sqldata)^ := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(RoundTo(Value * IBScaleDivisor[sqlscale], 0));
        SQL_LONG   : PInteger(sqldata)^  := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(RoundTo(Value * IBScaleDivisor[sqlscale], 0));
        SQL_INT64,
        SQL_QUAD   : PInt64(sqldata)^ := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(RoundTo(Value * IBScaleDivisor[sqlscale], 0));
        SQL_DOUBLE : PDouble(sqldata)^   := Value;
      else
        raise EZIBConvertError.Create(SUnsupportedDataType);
      end
    else
      case SQLCode of
        SQL_D_FLOAT,
        SQL_DOUBLE    : PDouble(sqldata)^   := Value;
        SQL_LONG      : PInteger(sqldata)^ := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(Value);
        SQL_FLOAT     : PSingle(sqldata)^ := Value;
        SQL_BOOLEAN   : PSmallint(sqldata)^ := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(Value);
        SQL_BOOLEAN_FB: PByte(sqldata)^ := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(Value);
        SQL_SHORT     : PSmallint(sqldata)^ := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(Value);
        SQL_INT64     : PInt64(sqldata)^ := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(Value);
        SQL_TEXT      : EncodeString(SQL_TEXT, Index, FloatToRaw(Value));
        SQL_VARYING   : EncodeString(SQL_VARYING, Index, FloatToRaw(Value));
      else
        raise EZIBConvertError.Create(SUnsupportedDataType);
      end;
    if (sqlind <> nil) then
       sqlind^ := 0; // not null
  end;
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
end;

{**
   Set up parameter Boolean value
   @param Index the target parameter index
   @param Value the source value
}
procedure TZParamsSQLDA.UpdateBoolean(const Index: Integer; const Value: boolean);
var
  SQLCode: SmallInt;
begin
  CheckRange(Index);
  {$R-}
  with FXSQLDA.sqlvar[Index] do
  begin
    if not FDecribedTypeArray[Index] = sqltype then
      SetFieldType(Index, FDecribedLengthArray[Index], FDecribedTypeArray[Index], FDecribedScaleArray[Index]);
    SQLCode := (sqltype and not(1));

    if (sqlscale < 0)  then
    begin
      case SQLCode of
        SQL_SHORT  : PSmallInt(sqldata)^ := ord(Value) * IBScaleDivisor[sqlscale];
        SQL_LONG   : PInteger(sqldata)^  := ord(Value) * IBScaleDivisor[sqlscale];
        SQL_INT64,
        SQL_QUAD   : PInt64(sqldata)^    := ord(Value) * IBScaleDivisor[sqlscale];
        SQL_DOUBLE : PDouble(sqldata)^   := ord(Value);
      else
        raise EZIBConvertError.Create(SUnsupportedParameterType);
      end;
    end
    else
      case SQLCode of
        SQL_D_FLOAT,
        SQL_DOUBLE    : PDouble(sqldata)^   := ord(Value);
        SQL_LONG      : PInteger(sqldata)^ := ord(Value);
        SQL_FLOAT     : PSingle(sqldata)^ := ord(Value);
        SQL_BOOLEAN   : PWordBool(sqldata)^ := Value;
        SQL_BOOLEAN_FB: PByte(sqldata)^ := Ord(Value);
        SQL_SHORT     : PSmallint(sqldata)^ := ord(Value);
        SQL_INT64     : PInt64(sqldata)^ := ord(Value);
        SQL_TEXT      : EncodeString(SQL_TEXT, Index, IntToRaw(ord(Value)));
        SQL_VARYING   : EncodeString(SQL_VARYING, Index, IntToRaw(ord(Value)));
      else
        raise EZIBConvertError.Create(SUnsupportedParameterType);
      end;
    if (sqlind <> nil) then
       sqlind^ := 0; // not null
  end;
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
end;

{**
   Set up parameter byte value
   @param Index the target parameter index
   @param Value the source value
}
procedure TZParamsSQLDA.UpdateBytes(const Index: Integer; const Value: TBytes);
var
 SQLCode: SmallInt;
begin
  CheckRange(Index);
  {$R-}
  with FXSQLDA.sqlvar[Index] do
  begin
    if not FDecribedTypeArray[Index] = sqltype then
      SetFieldType(Index, FDecribedLengthArray[Index], FDecribedTypeArray[Index], FDecribedScaleArray[Index]);
    SQLCode := (sqltype and not(1));
    case SQLCode of
      SQL_TEXT      : EncodePData(SQL_TEXT, Index, Pointer(Value), Length(Value));
      SQL_VARYING   : EncodePData(SQL_VARYING, Index, Pointer(Value), Length(Value));
      SQL_LONG      : PInteger (sqldata)^ := Round(RawToFloat(PAnsiChar(Pointer(Value)), AnsiChar('.')) * IBScaleDivisor[sqlscale]); //AVZ
      SQL_SHORT     : PSmallint(sqldata)^ := RawToInt(BytesToStr(Value));
      SQL_BOOLEAN   : PWordBool(sqldata)^ := StrToBoolEx(BytesToStr(Value));
      SQL_BOOLEAN_FB: PByte(sqldata)^ := Ord(StrToBoolEx(BytesToStr(Value)));
      SQL_TYPE_DATE : EncodeString(SQL_DATE, Index, BytesToStr(Value));
      SQL_D_FLOAT,
      SQL_DOUBLE    : PDouble (sqldata)^ := RawToFloat(PAnsiChar(Pointer(Value)), AnsiChar('.'))  * IBScaleDivisor[sqlscale]; //AVZ
      SQL_FLOAT     : PSingle (sqldata)^ := RawToFloat(PAnsiChar(Pointer(Value)), AnsiChar('.')) * IBScaleDivisor[sqlscale];  //AVZ
      SQL_INT64     : PInt64(sqldata)^ := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(RawToFloat(PAnsiChar(Pointer(Value)), AnsiChar('.')) * IBScaleDivisor[sqlscale]); //AVZ - INT64 value was not recognized
      SQL_BLOB,
      SQL_QUAD      : WriteLobBuffer(Index, Pointer(Value), Length(Value));
    else
      raise EZIBConvertError.Create(SErrorConvertion);
    end;
    if (sqlind <> nil) then
         sqlind^ := 0; // not null
  end;
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
end;

{**
   Set up parameter Date value
   @param Index the target parameter index
   @param Value the source value
}
procedure TZParamsSQLDA.UpdateDate(const Index: Integer; const Value: TDateTime);
begin
  SetFieldType(Index, sizeof(Integer), SQL_TYPE_DATE + 1, 0);
  UpdateDateTime(Index, Value);
end;

{**
   Set up parameter DateTime value
   @param Index the target parameter index
   @param Value the source value
}
procedure TZParamsSQLDA.UpdateDateTime(const Index: Integer;
  const Value: TDateTime);
var
  SQLCode: SmallInt;
  TmpDate: TZTimeStamp;//TCTimeStructure;
  P : Pointer;
begin
  CheckRange(Index);
  {$R-}
  with FXSQLDA.sqlvar[Index] do
  begin
    DecodeDate(Value, TmpDate.Year, TmpDate.Month, TmpDate.Day);
    TmpDate.Fractions := 0; //init
    DecodeTime(Value, TmpDate.Hour, TmpDate.Minute, TmpDate.Second, PWord(@TmpDate.Fractions)^);
    TmpDate.Fractions := TmpDate.Fractions*10;

    {if (sqlind <> nil) and (sqlind^ = -1) then Exit;}
    SQLCode := (sqltype and not(1));

    P := sqldata;
    case SQLCode of
      SQL_TYPE_DATE : isc_encode_date(PISC_DATE(P)^, TmpDate.Year, TmpDate.Month, TmpDate.Day);
      SQL_TYPE_TIME : isc_encode_time(PISC_TIME(sqldata)^, TmpDate.Hour, TmpDate.Minute, TmpDate.Second, TmpDate.Fractions);
      SQL_TIMESTAMP : begin
                        isc_encode_date(PISC_TIMESTAMP(sqldata).timestamp_date, TmpDate.Year, TmpDate.Month, TmpDate.Day);
                        isc_encode_time(PISC_TIMESTAMP(sqldata).timestamp_time, TmpDate.Hour, TmpDate.Minute, TmpDate.Second, TmpDate.Fractions);
                      end;
      else
        raise EZIBConvertError.Create(SInvalidState);
    end;
    if (sqlind <> nil) then
         sqlind^ := 0; // not null
  end;
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
end;

{**
   Set up parameter Double value
   @param Index the target parameter index
   @param Value the source value
}
procedure TZParamsSQLDA.UpdateDouble(const Index: Integer; const Value: Double);
var
  SQLCode: SmallInt;
begin
  CheckRange(Index);
  //SetFieldType(Index, sizeof(double), SQL_DOUBLE + 1, 0);
  {$R-}
  with FXSQLDA.sqlvar[Index] do
  begin
    if not FDecribedTypeArray[Index] = sqltype then
      SetFieldType(Index, FDecribedLengthArray[Index], FDecribedTypeArray[Index], FDecribedScaleArray[Index]);

    SQLCode := (sqltype and not(1));

    if (sqlscale < 0)  then
    begin
      //EH: Double is within Round(x: Real=Double) precision.
      case SQLCode of
        SQL_SHORT  : PSmallInt(sqldata)^ := Round(Value * IBScaleDivisor[sqlscale]);
        SQL_LONG   : PInteger(sqldata)^  := Round(Value * IBScaleDivisor[sqlscale]);
        SQL_INT64,
        SQL_QUAD   : PInt64(sqldata)^    := Round(Value * IBScaleDivisor[sqlscale]);
        SQL_DOUBLE : PDouble(sqldata)^   := Value;
      else
        raise EZIBConvertError.Create(SUnsupportedDataType);
      end;
    end
    else
      case SQLCode of
        SQL_D_FLOAT,
        SQL_DOUBLE    : PDouble(sqldata)^   := Value;
        SQL_LONG      : PInteger(sqldata)^ := Round(Value);
        SQL_FLOAT     : PSingle(sqldata)^ := Value;
        SQL_BOOLEAN   : PSmallint(sqldata)^ := Round(Value);
        SQL_BOOLEAN_FB: PByte(sqldata)^ := Round(Value);
        SQL_SHORT     : PSmallint(sqldata)^ := Round(Value);
        SQL_INT64     : PInt64(sqldata)^ := Round(Value);
        SQL_TEXT      : EncodeString(SQL_TEXT, Index, FloatToRaw(Value));
        SQL_VARYING   : EncodeString(SQL_VARYING, Index, FloatToRaw(Value));
      else
        raise EZIBConvertError.Create(SUnsupportedDataType);
      end;
      if (sqlind <> nil) then
         sqlind^ := 0; // not null
  end;
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
end;

{**
   Set up parameter Float value
   @param Index the target parameter index
   @param Value the source value
}
procedure TZParamsSQLDA.UpdateFloat(const Index: Integer; const Value: Single);
var
  SQLCode: SmallInt;
begin
  CheckRange(Index);

  {$R-}
  with FXSQLDA.sqlvar[Index] do
  begin
    if not FDecribedTypeArray[Index] = sqltype then
      SetFieldType(Index, FDecribedLengthArray[Index], FDecribedTypeArray[Index], FDecribedScaleArray[Index]);

    SQLCode := (sqltype and not(1));

    if (sqlscale < 0)  then
    begin
      case SQLCode of
        SQL_SHORT  : PSmallInt(sqldata)^ := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(Value * IBScaleDivisor[sqlscale]);
        SQL_LONG   : PInteger(sqldata)^  := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(Value * IBScaleDivisor[sqlscale]);
        SQL_INT64,
        SQL_QUAD   : PInt64(sqldata)^    := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(Value * IBScaleDivisor[sqlscale]);
        SQL_DOUBLE : PDouble(sqldata)^   := Value;
        SQL_D_FLOAT,
        SQL_FLOAT  : PSingle(sqldata)^   := Value;
      else
        raise EZIBConvertError.Create(SUnsupportedDataType);
      end;
    end
    else
      case SQLCode of
        SQL_D_FLOAT,
        SQL_DOUBLE    : PDouble(sqldata)^   := Value;
        SQL_LONG      : PInteger(sqldata)^ := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(Value);
        SQL_FLOAT     : PSingle(sqldata)^ := Value;
        SQL_BOOLEAN   : PSmallint(sqldata)^ := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(Value);
        SQL_BOOLEAN_FB: PByte(sqldata)^ := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(Value);
        SQL_SHORT     : PSmallint(sqldata)^ := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(Value);
        SQL_INT64     : PInt64(sqldata)^ := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(Value);
        SQL_TEXT      : EncodeString(SQL_TEXT, Index, FloatToRaw(Value));
        SQL_VARYING   : EncodeString(SQL_VARYING, Index, FloatToRaw(Value));
      else
        raise EZIBConvertError.Create(SUnsupportedDataType);
      end;
      if (sqlind <> nil) then
         sqlind^ := 0; // not null
  end;
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
end;

{**
   Set up parameter integer value
   @param Index the target parameter index
   @param Value the source value
}
procedure TZParamsSQLDA.UpdateInt(const Index: Integer; const Value: Integer);
var
  SQLCode: SmallInt;
begin
  CheckRange(Index);
  {$R-}
  with FXSQLDA.sqlvar[Index] do
  begin
    if not FDecribedTypeArray[Index] = sqltype then
      SetFieldType(Index, FDecribedLengthArray[Index], FDecribedTypeArray[Index], FDecribedScaleArray[Index]);
    SQLCode := (sqltype and not(1));

    if (sqlscale < 0)  then
    begin
      case SQLCode of
        SQL_SHORT  : PSmallInt(sqldata)^ := Value * IBScaleDivisor[sqlscale];
        SQL_LONG   : PInteger(sqldata)^  := Value * IBScaleDivisor[sqlscale];
        SQL_INT64,
        SQL_QUAD   : PInt64(sqldata)^    := Value * IBScaleDivisor[sqlscale];
        SQL_DOUBLE : PDouble(sqldata)^   := Value;
      else
        raise EZIBConvertError.Create(SUnsupportedDataType);
      end;
    end
    else
      case SQLCode of
        SQL_D_FLOAT,
        SQL_DOUBLE    : PDouble(sqldata)^   := Value;
        SQL_LONG      : PInteger(sqldata)^ := Value;
        SQL_FLOAT     : PSingle(sqldata)^ := Value;
        SQL_BOOLEAN   : PSmallint(sqldata)^ := Value;
        SQL_BOOLEAN_FB: PByte(sqldata)^ := Value;
        SQL_SHORT     : PSmallint(sqldata)^ := Value;
        SQL_INT64     : PInt64(sqldata)^ := Value;
        SQL_TEXT      : EncodeString(SQL_TEXT, Index, IntToRaw(Value));
        SQL_VARYING   : EncodeString(SQL_VARYING, Index, IntToRaw(Value));
      else
        raise EZIBConvertError.Create(SUnsupportedDataType);
      end;
      if (sqlind <> nil) then
         sqlind^ := 0; // not null
  end;
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
end;

{**
   Set up parameter Long value
   @param Index the target parameter index
   @param Value the source value
}
procedure TZParamsSQLDA.UpdateLong(const Index: integer; const Value: Int64);
var
  SQLCode: SmallInt;
begin
  CheckRange(Index);
  {$R-}
  with FXSQLDA.sqlvar[Index] do
  begin
    if not FDecribedTypeArray[Index] = sqltype then
      SetFieldType(Index, FDecribedLengthArray[Index], FDecribedTypeArray[Index], FDecribedScaleArray[Index]);

    SQLCode := (sqltype and not(1));

    if (sqlscale < 0)  then
    begin
      case SQLCode of
        SQL_SHORT  : PSmallInt(sqldata)^ := Value * IBScaleDivisor[sqlscale];
        SQL_LONG   : PInteger(sqldata)^  := Value * IBScaleDivisor[sqlscale];
        SQL_INT64,
        SQL_QUAD   : PInt64(sqldata)^    := Value * IBScaleDivisor[sqlscale];
        SQL_DOUBLE : PDouble(sqldata)^   := Value;
      else
        raise EZIBConvertError.Create(SUnsupportedDataType);
      end;
    end
    else
      case SQLCode of
        SQL_D_FLOAT,
        SQL_DOUBLE    : PDouble(sqldata)^   := Value;
        SQL_LONG      : PInteger(sqldata)^ := Value;
        SQL_FLOAT     : PSingle(sqldata)^ := Value;
        SQL_BOOLEAN   : PSmallint(sqldata)^ := Value;
        SQL_BOOLEAN_FB: PByte(sqldata)^ := Value;
        SQL_SHORT     : PSmallint(sqldata)^ := Value;
        SQL_INT64     : PInt64(sqldata)^ := Value;
        SQL_TEXT      : EncodeString(SQL_TEXT, Index, IntToRaw(Value));
        SQL_VARYING   : EncodeString(SQL_VARYING, Index, IntToRaw(Value));
      else
        raise EZIBConvertError.Create(SUnsupportedDataType);
      end;
      if (sqlind <> nil) then
         sqlind^ := 0; // not null
  end;
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
end;

{**
   Set up parameter null value
   @param Index the target parameter index
   @param Value the source value
}
procedure TZParamsSQLDA.UpdateNull(const Index: Integer; const Value: boolean);
begin
  CheckRange(Index);
  {$R-}
  with FXSQLDA.sqlvar[Index] do
    if (sqlind <> nil) then
       sqlind^ := -Ord(Value);
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
end;

{**
   Set up parameter PAnsiChar value
   @param Index the target parameter index
   @param Value the source value
}
procedure TZParamsSQLDA.UpdatePAnsiChar(const Index: Integer; const Value: PAnsiChar; const Len: Cardinal);
var
 SQLCode: SmallInt;
 TempTimeStamp: TDateTime;
 Failed: Boolean;
begin
  CheckRange(Index);
  {$R-}
  with FXSQLDA.sqlvar[Index] do
  begin
    if not FDecribedTypeArray[Index] = sqltype then
      SetFieldType(Index, FDecribedLengthArray[Index], FDecribedTypeArray[Index], FDecribedScaleArray[Index]);

    SQLCode := (sqltype and not(1));
    case SQLCode of
      SQL_TEXT      : EncodePData(SQLCode, Index, Value, Len);
      SQL_VARYING   : EncodePData(SQLCode, Index, Value, Len);
      SQL_LONG      : PInteger (sqldata)^ := RawToIntDef(Value, 0);
      SQL_SHORT     : PSmallint (sqldata)^ := RawToIntDef(Value, 0);
      SQL_BOOLEAN   : PWordBool(sqldata)^ := StrToBoolEx(Value);
      SQL_BOOLEAN_FB: PByte(sqldata)^ := Ord(StrToBoolEx(Value));
      SQL_D_FLOAT,
      SQL_DOUBLE    : SQLStrToFloatDef(Value, 0, PDouble(sqldata)^);
      SQL_FLOAT     : SQLStrToFloatDef(Value, 0, PSingle (sqldata)^);
      SQL_INT64     : PInt64(sqldata)^ := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(RoundTo(SQLStrToFloatDef(Value, 0, Len) * IBScaleDivisor[sqlscale], 0)); //AVZ - INT64 value was not recognized
      SQL_BLOB, SQL_QUAD: WriteLobBuffer(Index, Value, Len);
      SQL_TYPE_DATE :
        begin
          if (Len = 0) or (PByte(Value+2)^ = Ord(':')) then
            TempTimeStamp := 0
          else if Len = ConSettings^.WriteFormatSettings.DateFormatLen then
            TempTimeStamp := RawSQLDateToDateTime(Value,  Len, ConSettings^.WriteFormatSettings, Failed)
          else
            TempTimeStamp := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(
              RawSQLTimeStampToDateTime(Value, Len, ConSettings^.WriteFormatSettings, Failed));
          UpdateDateTime(Index, TempTimeStamp);
        end;
      SQL_TYPE_TIME:
        begin
          if Len = 0 then
            TempTimeStamp := 0
          else if PByte(Value+2)^ = Ord(':') then //possible date if Len = 10 then
            TempTimeStamp := RawSQLTimeToDateTime(Value,Len, ConSettings^.WriteFormatSettings, Failed)
          else
            TempTimeStamp := Frac(RawSQLTimeStampToDateTime(Value, Len, ConSettings^.WriteFormatSettings, Failed));
          UpdateDateTime(Index, TempTimeStamp);
        end;
      SQL_TIMESTAMP:
        begin
          if Len = 0 then
            TempTimeStamp := 0
          else
            if PByte(Value+2)^ = Ord(':') then
              TempTimeStamp := RawSQLTimeToDateTime(Value, Len, ConSettings^.WriteFormatSettings, Failed)
            else if (ConSettings^.WriteFormatSettings.DateTimeFormatLen - Len) <= 4 then
              TempTimeStamp := RawSQLTimeStampToDateTime(Value, Len, ConSettings^.WriteFormatSettings, Failed)
            else if PByte(Value+4)^ = Ord('-') then
              TempTimeStamp := RawSQLDateToDateTime(Value,  Len, ConSettings^.WriteFormatSettings, Failed)
            else
              TempTimeStamp := RawSQLTimeToDateTime(Value, Len, ConSettings^.WriteFormatSettings, Failed);
          UpdateDateTime(Index, TempTimeStamp);
        end;
    else
      raise EZIBConvertError.Create(SErrorConvertion);
    end;
    if (sqlind <> nil) then
         sqlind^ := 0; // not null
  end;
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
end;

{**
   Set up parameter Interbase QUAD value
   @param Index the target parameter index
   @param Value the source value
}
procedure TZParamsSQLDA.UpdateQuad(const Index: Word; const Value: TISC_QUAD);
begin
  CheckRange(Index);
  {$R-}
  with FXSQLDA.sqlvar[Index] do
    if not ((sqlind <> nil) and (sqlind^ = -1)) then
      case (sqltype and not(1)) of
        SQL_QUAD, SQL_DOUBLE, SQL_INT64, SQL_BLOB, SQL_ARRAY:
          begin
            PISC_QUAD(sqldata)^ := Value;
            sqlind^ := 0; // not null
          end;
      else
        raise EZIBConvertError.Create(SErrorConvertion);
      end
    else
      if (sqlind <> nil) then
        case (sqltype and not(1)) of
          SQL_QUAD, SQL_DOUBLE, SQL_INT64, SQL_BLOB, SQL_ARRAY:
            begin
              sqlind^ := 0; // not null
              PISC_QUAD(sqldata)^ := Value
            end
          else
            raise EZIBConvertError.Create(SErrorConvertion);
        end;
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
end;

procedure TZParamsSQLDA.UpdateArray(const Index: Word; const Value; const SQLType: TZSQLType;
  const VariantType: TZVariantType = vtNull);
//var
  //SQLCode: SmallInt;
begin
  CheckRange(Index);
  {$R-}
  with FXSQLDA.sqlvar[Index] do
  begin
    if not FDecribedTypeArray[Index] = sqltype then
      SetFieldType(Index, SizeOf(TISC_QUAD), SQL_ARRAY, 0);
    if (sqlind <> nil) and (sqlind^ = -1) then
       Exit;
//    SQLCode := (sqltype and not(1));
    (*
    if (sqlscale < 0)  then
    begin
      case SQLCode of
        SQL_SHORT  : PSmallInt(sqldata)^ := Value * IBScaleDivisor[sqlscale];
        SQL_LONG   : PInteger(sqldata)^  := Value * IBScaleDivisor[sqlscale];
        SQL_INT64,
        SQL_QUAD   : PInt64(sqldata)^    := Value * IBScaleDivisor[sqlscale];
        SQL_DOUBLE : PDouble(sqldata)^   := Value;
      else
        raise EZIBConvertError.Create(SUnsupportedParameterType);
      end;
    end
    else
      case SQLCode of
        SQL_D_FLOAT,
        SQL_DOUBLE    : PDouble(sqldata)^   := Value;
        SQL_LONG      : PInteger(sqldata)^ := Value;
        SQL_FLOAT     : PSingle(sqldata)^ := Value;
        SQL_BOOLEAN:
                     begin
                       if FPlainDriver.GetProtocol <> 'interbase-7' then
                         raise EZIBConvertError.Create(SUnsupportedDataType);
                       PSmallint(sqldata)^ := Value;
                     end;
        SQL_BOOLEAN   : ...
        SQL_SHORT     : PSmallint(sqldata)^ := Value;
        SQL_INT64     : PInt64(sqldata)^ := Value;
        SQL_TEXT      : EncodeString(SQL_TEXT, Index, IntToRaw(Value));
        SQL_VARYING   : EncodeString(SQL_VARYING, Index, IntToRaw(Value));
      else
        raise EZIBConvertError.Create(SUnsupportedParameterType);
      end;*)
    if (sqlind <> nil) then
       sqlind^ := 0; // not null
  end;
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
end;
{**
   Set up parameter Byte value
   @param Index the target parameter index
   @param Value the source value
}
procedure TZParamsSQLDA.UpdateSmall(const Index: Integer; const Value: SmallInt);
var
  SQLCode: SmallInt;
begin
  CheckRange(Index);
  {$R-}
  with FXSQLDA.sqlvar[Index] do
  begin
    if not FDecribedTypeArray[Index] = sqltype then
      SetFieldType(Index, FDecribedLengthArray[Index], FDecribedTypeArray[Index], FDecribedScaleArray[Index]);
    SQLCode := (sqltype and not(1));

    if (sqlscale < 0)  then
    begin
      case SQLCode of
        SQL_SHORT  : PSmallInt(sqldata)^ := Value * IBScaleDivisor[sqlscale];
        SQL_LONG   : PInteger(sqldata)^  := Value * IBScaleDivisor[sqlscale];
        SQL_INT64,
        SQL_QUAD   : PInt64(sqldata)^    := Value * IBScaleDivisor[sqlscale];
        SQL_DOUBLE : PDouble(sqldata)^   := Value;
      else
        raise EZIBConvertError.Create(SUnsupportedParameterType);
      end;
    end
    else
      case SQLCode of
        SQL_D_FLOAT,
        SQL_DOUBLE    : PDouble(sqldata)^   := Value;
        SQL_LONG      : PInteger(sqldata)^ := Value;
        SQL_FLOAT     : PSingle(sqldata)^ := Value;
        SQL_BOOLEAN:
                     begin
                       if FPlainDriver.GetProtocol <> 'interbase-7' then
                         raise EZIBConvertError.Create(SUnsupportedDataType);
                       PSmallint(sqldata)^ := Value;
                     end;
        SQL_BOOLEAN_FB: PByte(sqldata)^ := Value;
        SQL_SHORT     : PSmallint(sqldata)^ := Value;
        SQL_INT64     : PInt64(sqldata)^ := Value;
        SQL_TEXT      : EncodeString(SQL_TEXT, Index, IntToRaw(Value));
        SQL_VARYING   : EncodeString(SQL_VARYING, Index, IntToRaw(Value));
      else
        raise EZIBConvertError.Create(SUnsupportedParameterType);
      end;
    if (sqlind <> nil) then
       sqlind^ := 0; // not null
  end;
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
end;

{**
   Set up parameter Time value
   @param Index the target parameter index
   @param Value the source value
}
procedure TZParamsSQLDA.UpdateTime(const Index: Integer; const Value: TDateTime);
begin
  SetFieldType(Index, sizeof(Cardinal), SQL_TYPE_TIME + 1, 0);
  UpdateDateTime(Index, Value);
end;

{**
   Set up parameter Timestamp value
   @param Index the target parameter index
   @param Value the source value
}
procedure TZParamsSQLDA.UpdateTimestamp(const Index: Integer; const Value: TDateTime);
begin
  SetFieldType(Index, sizeof(TISC_QUAD), SQL_TIMESTAMP + 1, 0);
  UpdateDateTime(Index, Value);
end;

procedure TZParamsSQLDA.WriteLobBuffer(const Index: Integer;
  const Buffer: Pointer; const Len: Integer);
var
  BlobId: TISC_QUAD;
  BlobHandle: TISC_BLOB_HANDLE;
  StatusVector: TARRAY_ISC_STATUS;
  CurPos, SegLen: Integer;
  TempBuffer: PAnsiChar;
begin
  BlobHandle := 0;

  { create blob handle }
  with (FConnection as IZInterbase6Connection) do
    if FPlainDriver.isc_create_blob2(@StatusVector, GetDBHandle, GetTrHandle,
      @BlobHandle, @BlobId, 0, nil) <> 0 then
    CheckInterbase6Error(FPlainDriver, StatusVector, Self);

  { put data to blob }
  TempBuffer := Buffer;
  CurPos := 0;
  SegLen := DefaultBlobSegmentSize;
  while (CurPos < Len) do begin
    if (CurPos + SegLen > Len) then
      SegLen := Len - CurPos;
    if FPlainDriver.isc_put_segment(@StatusVector, @BlobHandle, SegLen, TempBuffer) <> 0 then
      CheckInterbase6Error(FPlainDriver, StatusVector, Self);
    Inc(CurPos, SegLen);
    Inc(TempBuffer, SegLen);
  end;

  { close blob handle }
  if FPlainDriver.isc_close_blob(@StatusVector, @BlobHandle) <> 0 then
    CheckInterbase6Error(FPlainDriver, StatusVector, Self);

  UpdateQuad(Index, BlobId);
end;

const
  EBStart = {$IFNDEF NO_ANSISTRING}AnsiString{$ELSE}RawByteString{$ENDIF}('EXECUTE BLOCK(');
  EBBegin =  {$IFNDEF NO_ANSISTRING}AnsiString{$ELSE}RawByteString{$ENDIF}(')AS BEGIN'+LineEnding);
  EBSuspend =  {$IFNDEF NO_ANSISTRING}AnsiString{$ELSE}RawByteString{$ENDIF}('SUSPEND;'+LineEnding); //required for RETURNING syntax
  EBEnd = {$IFNDEF NO_ANSISTRING}AnsiString{$ELSE}RawByteString{$ENDIF}('END');
  LBlockLen = Length(EBStart)+Length(EBBegin)+Length(EBEnd);

function GetExecuteBlockString(const ParamsSQLDA: IZParamsSQLDA;
  const IsParamIndexArray: TBooleanDynArray;
  const InParamCount, RemainingArrayRows: Integer;
  const CurrentSQLTokens: TRawByteStringDynArray;
  const PlainDriver: TZInterbasePlainDriver;
  var MemPerRow, PreparedRowsOfArray,MaxRowsPerBatch: Integer;
  var TypeTokens: TRawByteStringDynArray;
  InitialStatementType: TZIbSqlStatementType;
  const XSQLDAMaxSize: LongWord): RawByteString;
var
  IndexName, ArrayName: RawByteString;
  I, j, BindCount, ParamIndex, ParamNameLen, SingleStmtLength, LastStmLen,
  HeaderLen, FullHeaderLen, StmtLength:  Integer;
  CodePageInfo: PZCodePage;
  PStmts, PResult, P: PAnsiChar;
  ReturningFound: Boolean;

  procedure Put(const Args: array of RawByteString; var Dest: PAnsiChar);
  var I: Integer;
  begin
    for I := low(Args) to high(Args) do //Move data
    begin
      {$IFDEF FAST_MOVE}ZFastCode{$ELSE}System{$ENDIF}.Move(Pointer(Args[i])^, Dest^, {%H-}PLengthInt(NativeUInt(Args[i]) - StringLenOffSet)^);
      Inc(Dest, {%H-}PLengthInt(NativeUInt(Args[i]) - StringLenOffSet)^);
    end;
  end;
  procedure AddParam(const Args: array of RawByteString; var Dest: RawByteString);
  var I, L: Integer;
    P: PAnsiChar;
  begin
    Dest := ''; L := 0;
    for I := low(Args) to high(Args) do //Calc String Length
      Inc(L ,Length(Args[i]));
    SetLength(Dest, L);
    P := Pointer(Dest);
    Put(Args, P);
  end;
  function GetIntDigits(Value: Integer): Integer;
  begin
    if Value >= 10000 then
      if Value >= 1000000 then
        if Value >= 100000000 then
          Result := 9 + Ord(Value >= 1000000000)
        else
          Result := 7 + Ord(Value >= 10000000)
      else
        Result := 5 + Ord(Value >= 100000)
    else
      if Value >= 100 then
        Result := 3 + Ord(Value >= 1000)
      else
        Result := 1 + Ord(Value >= 10);
  end;
begin
  if Pointer(TypeTokens) = nil then
  begin
    BindCount := ParamsSQLDA.GetFieldCount;
    Assert(InParamCount=BindCount, 'ParamCount missmatch');
    SetLength(TypeTokens, BindCount);
    MemPerRow := 0;
    for ParamIndex := 0 to BindCount-1 do
    begin
      case ParamsSQLDA.GetIbSqlType(ParamIndex) and not (1) of
        SQL_VARYING:
          begin
            CodePageInfo := PlainDriver.ValidateCharEncoding(ParamsSQLDA.GetIbSqlSubType(ParamIndex));
            AddParam([' VARCHAR(', IntToRaw(ParamsSQLDA.GetIbSqlLen(ParamIndex) div CodePageInfo.CharWidth),
            ') CHARACTER SET ', {$IFDEF UNICODE}UnicodeStringToASCII7{$ENDIF}(CodePageInfo.Name), ' = ?' ], TypeTokens[ParamIndex]);
          end;
        SQL_TEXT:
          begin
            CodePageInfo := PlainDriver.ValidateCharEncoding(ParamsSQLDA.GetIbSqlSubType(ParamIndex));
            AddParam([' CHAR(', IntToRaw(ParamsSQLDA.GetIbSqlLen(ParamIndex) div CodePageInfo.CharWidth),
            ') CHARACTER SET ', {$IFDEF UNICODE}UnicodeStringToASCII7{$ENDIF}(CodePageInfo.Name), ' = ?' ], TypeTokens[ParamIndex]);
          end;
        SQL_DOUBLE, SQL_D_FLOAT:
           AddParam([' DOUBLE PRECISION=?'], TypeTokens[ParamIndex]);
        SQL_FLOAT:
           AddParam([' FLOAT=?'],TypeTokens[ParamIndex]);
        SQL_LONG:
          if ParamsSQLDA.GetFieldScale(ParamIndex) = 0 then
            AddParam([' INTEGER=?'],TypeTokens[ParamIndex])
          else
            if ParamsSQLDA.GetIbSqlSubType(ParamIndex) = RDB_NUMBERS_NUMERIC then
              AddParam([' NUMERIC(9,', IntToRaw(ParamsSQLDA.GetFieldScale(ParamIndex)),')=?'], TypeTokens[ParamIndex])
            else
              AddParam([' DECIMAL(9', IntToRaw(ParamsSQLDA.GetFieldScale(ParamIndex)), ',', IntToRaw(ParamsSQLDA.GetFieldScale(ParamIndex)),')=?'],TypeTokens[ParamIndex]);
        SQL_SHORT:
          if ParamsSQLDA.GetFieldScale(ParamIndex) = 0 then
            AddParam([' SMALLINT=?'],TypeTokens[ParamIndex])
          else
            if ParamsSQLDA.GetIbSqlSubType(ParamIndex) = RDB_NUMBERS_NUMERIC then
              AddParam([' NUMERIC(4,', IntToRaw(ParamsSQLDA.GetFieldScale(ParamIndex)),')=?'],TypeTokens[ParamIndex])
            else
              AddParam([' DECIMAL(4', IntToRaw(ParamsSQLDA.GetFieldScale(ParamIndex)), ',', IntToRaw(ParamsSQLDA.GetFieldScale(ParamIndex)),')=?'],TypeTokens[ParamIndex]);
        SQL_TIMESTAMP:
           AddParam([' TIMESTAMP=?'],TypeTokens[ParamIndex]);
        SQL_BLOB:
          if ParamsSQLDA.GetIbSqlSubType(ParamIndex) = isc_blob_text then
            AddParam([' BLOB SUB_TYPE TEXT=?'],TypeTokens[ParamIndex])
          else
            AddParam([' BLOB=?'],TypeTokens[ParamIndex]);
        //SQL_ARRAY                      = 540;
        //SQL_QUAD                       = 550;
        SQL_TYPE_TIME:
           AddParam([' TIME=?'],TypeTokens[ParamIndex]);
        SQL_TYPE_DATE:
           AddParam([' DATE=?'],TypeTokens[ParamIndex]);
        SQL_INT64: // IB7
          if ParamsSQLDA.GetFieldScale(ParamIndex) = 0 then
            AddParam([' BIGINT=?'],TypeTokens[ParamIndex])
          else
            if ParamsSQLDA.GetIbSqlSubType(ParamIndex) = RDB_NUMBERS_NUMERIC then
              AddParam([' NUMERIC(18,', IntToRaw(ParamsSQLDA.GetFieldScale(ParamIndex)),')=?'],TypeTokens[ParamIndex])
            else
              AddParam([' DECIMAL(18,', IntToRaw(ParamsSQLDA.GetFieldScale(ParamIndex)),')=?'],TypeTokens[ParamIndex]);
        SQL_BOOLEAN, SQL_BOOLEAN_FB{FB30}:
           AddParam([' BOOLEAN=?'],TypeTokens[ParamIndex]);
        SQL_NULL{FB25}:
           AddParam([' CHAR(1)=?'],TypeTokens[ParamIndex]);
      end;
      Inc(MemPerRow, ParamsSQLDA.GetFieldLength(ParamIndex) +
        2*Ord((ParamsSQLDA.GetIbSqlType(ParamIndex) and not 1) = SQL_VARYING));
    end;
    Inc(MemPerRow, XSQLDA_LENGTH(InParamCount));
  end;
  {now let's calc length of stmt to know if we can bound all array data or if we need some more calls}
  StmtLength := 0;
  FullHeaderLen := 0;
  ReturningFound := False;
  PreparedRowsOfArray := 0;

  for J := 0 to RemainingArrayRows -1 do
  begin
    ParamIndex := 0;
    SingleStmtLength := 0;
    LastStmLen := StmtLength;
    HeaderLen := 0;
    for i := low(CurrentSQLTokens) to high(CurrentSQLTokens) do begin
      if IsParamIndexArray[i] then begin //calc Parameters size
        ParamNameLen := {P}1+GetIntDigits(ParamIndex)+1{_}+GetIntDigits(j);
        {inc header}
        Inc(HeaderLen, ParamNameLen+ {%H-}PLengthInt(NativeUInt(TypeTokens[ParamIndex]) - StringLenOffSet)^+Ord(not ((ParamIndex = 0) and (J=0))){,});
        {inc stmt}
        Inc(SingleStmtLength, 1+{:}ParamNameLen);
        Inc(ParamIndex);
      end else begin
        Inc(SingleStmtLength, {%H-}PLengthInt(NativeUInt(CurrentSQLTokens[i]) - StringLenOffSet)^);
        P := Pointer(CurrentSQLTokens[i]);
        if not ReturningFound and (Ord(P^) in [Ord('R'), Ord('r')]) then begin
          ReturningFound := {$IFDEF WITH_UNITANSISTRINGS}AnsiStrings.{$ENDIF}UpperCase(CurrentSQLTokens[i]) = 'RETURNING';
          Inc(StmtLength, Ord(ReturningFound)*Length(EBSuspend));
        end;
      end;
    end;
    Inc(SingleStmtLength, 1{;}+Length(LineEnding));
    if MaxRowsPerBatch = 0 then //calc maximum batch count if not set already
      MaxRowsPerBatch := Min((XSQLDAMaxSize div Cardinal(MemPerRow)),     {memory limit of XSQLDA structs}
        (((32*1024)-LBlockLen) div Cardinal(HeaderLen+SingleStmtLength)))+1; {32KB limited Also with FB3};
    Inc(StmtLength, HeaderLen+SingleStmtLength);
    Inc(FullHeaderLen, HeaderLen);
    //we run into XSQLDA !update! count limit of 255 see:
    //http://tracker.firebirdsql.org/browse/CORE-3027?page=com.atlassian.jira.plugin.system.issuetabpanels%3Aall-tabpanel
    if (PreparedRowsOfArray = MaxRowsPerBatch-1) or
       ((InitialStatementType <> stInsert) and (PreparedRowsOfArray > 255)) then begin
      StmtLength := LastStmLen;
      Dec(FullHeaderLen, HeaderLen);
      Break;
    end else
      PreparedRowsOfArray := J;
  end;

  {EH: now move our data to result ! ONE ALLOC ! of result (: }
  SetLength(Result, StmtLength+LBlockLen);
  PResult := Pointer(Result);
  Put([EBStart], PResult);
  PStmts := PResult + FullHeaderLen+Length(EBBegin);
  for J := 0 to PreparedRowsOfArray do begin
    ParamIndex := 0;
    for i := low(CurrentSQLTokens) to high(CurrentSQLTokens) do begin
      if IsParamIndexArray[i] then begin
        IndexName := IntToRaw(ParamIndex);
        ArrayName := IntToRaw(J);
        Put([':P', IndexName, '_', ArrayName], PStmts);
        if (ParamIndex = 0) and (J=0)
        then Put(['P', IndexName, '_', ArrayName, TypeTokens[ParamIndex]], PResult)
        else Put([',P', IndexName, '_', ArrayName, TypeTokens[ParamIndex]], PResult);
        Inc(ParamIndex);
      end else
        Put([CurrentSQLTokens[i]], PStmts);
    end;
    Put([';',LineEnding], PStmts);
  end;
  Put([EBBegin], PResult);
  if ReturningFound then
    Put([EBSuspend], PStmts);
  Put([EBEnd], PStmts);
  Inc(PreparedRowsOfArray);
end;

procedure isc_decode_time(ntime: ISC_TIME; out hours, minutes, seconds: Word; out fractions: LongWord);
begin
  hours := ntime div (SecsPerHour * ISC_TIME_SECONDS_PRECISION);
  ntime := ntime mod (SecsPerHour * ISC_TIME_SECONDS_PRECISION);
  minutes := ntime div (SecsPerMin * ISC_TIME_SECONDS_PRECISION);
  ntime := ntime mod (SecsPerMin * ISC_TIME_SECONDS_PRECISION);
  seconds := ntime div ISC_TIME_SECONDS_PRECISION;
  fractions := ntime mod ISC_TIME_SECONDS_PRECISION;
end;

{$IFDEF FPC} {$PUSH} {$WARN 4081 off : Converting the operands to "$1" before doing the multiply could prevent overflow errors.} {$ENDIF} // overflow means error so just disable hint
procedure isc_encode_time(var ntime: ISC_TIME; hours, minutes, seconds: Word; fractions: LongWord);
begin
  ntime := ((hours * MinsPerHour + minutes) * SecsPerMin + seconds) * ISC_TIME_SECONDS_PRECISION + fractions;
end;
{$IFDEF FPC} {$POP} {$ENDIF}

const
  //see https://stackoverflow.com/questions/5248827/convert-datetime-to-julian-date-in-c-sharp-tooadate-safe
  JD_Offset             = 1721119; //This is the Julian Date of March 2nd, 1 BC. Since we moved the 'start' of the calendar from January to March, we use this as our offset
  JDZeroFromGMT         = 2400001; //Julian Date Zero (from noon GMT)
  IB_BaseDateToDay0Diff  = (JDZeroFromGMT-JD_Offset); //number of days from 0/0/0000 to IB/FB base date
  Day0ToIB_BaseDateDiff  = (JD_Offset-JDZeroFromGMT); //number of days from IB/FB base date to 0/0/0000
  DaysOf4YearCycle      = 1461;
  DaysOf400YearsCycle   = 146097; //400 years contain 146097 https://wiki.osdev.org/Julian_Day_Number
  Aug8th                = 153; //8. August

//This formula is taken from the 1939 edition of Funk & Wagnall's College Standard Dictionary (entry for the word "calendar").
//so there is no IB/FB "hokuspokus" to play with encode/decode
{$IFDEF FPC} {$PUSH} {$WARN 4081 off : Converting the operands to "$1" before doing the multiply could prevent overflow errors.} {$ENDIF} // overflow means error so just disable hint
procedure isc_decode_date(nday: ISC_DATE; out year, month, day: Word);
var century: integer;
begin
  nday := nday + IB_BaseDateToDay0Diff;
  century := (4 * nday - 1) div DaysOf400YearsCycle;
  nday := 4 * nday - 1 - DaysOf400YearsCycle * century;
  day := nday div 4;

  nday := (4 * day + 3) div DaysOf4YearCycle;
  day  := 4 * day + 3 - DaysOf4YearCycle * nday;
  day := (day + 4) div 4;

  month := (5 * day - 3) div Aug8th;
  day := 5 * day - 3 - Aug8th * month;
  day := (day + 5) div 5;

  year := 100 * century + nday;

  if (month < 10) then
    month := month +3
  else begin
    month := month-9;
    year := year +1;
  end;
end;

procedure isc_encode_date(out nday: ISC_DATE; year, month, day: word);
var century, year_anno: Integer;
begin
  if (month > 2) then
    month := month -3
  else begin
    month := month + 9;
    year := year -1;
  end;

  century := year div 100;
  year_anno := year - 100 * century;
  nday := ((Int64(DaysOf400YearsCycle * century)) div 4 +
           (DaysOf4YearCycle * year_anno) div 4 +
           (Aug8th * month + 2) div 5 + day + Day0ToIB_BaseDateDiff);
end;
{$IFDEF FPC} {$POP} {$ENDIF}

end.
