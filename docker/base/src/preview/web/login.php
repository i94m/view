<?php
/*
 * 自动登录版 login.php（镜像自带，/opt/preview/web/login.php）。
 *
 * 相对仓库里的 web/login.php：只保留
 *   - 启动所需的 define / require
 *   - 按邮箱自动登录（登录后直接 die()）
 *   - userLogin() / checkFunctionalRole() 两个函数（原文件里定义在 die 之后，
 *     少了它们自动登录会报 undefined function）
 * 登录表单的渲染代码全部删除。
 *
 * 登录邮箱取环境变量 VIEW_USERNAME（与 Playwright 用的是同一个），
 * 对应 user 表的 Username 字段；站点配置来自只读挂载的 config.php。
 */

define('NO_USER_REQUIRED', true);
define('NO_CLOSE_SESSION', TRUE);
define('NO_PERMISSION_REQUIRED', true);

require_once("{$_SERVER["DOCUMENT_ROOT"]}/../sys/libs/init.lib");
require_once("{$_SERVER["DOCUMENT_ROOT"]}/../sys/libs/logic/SystemAdmin/User/Service/UserInformationService.php");
use SystemAdmin\User\Service\UserInformationService as UserInformationService;

$loginName = trim((string) getenv('VIEW_USERNAME'));
if ($loginName === '') {
	die('VIEW_USERNAME 未设置，无法自动登录（用登录邮箱，例如 VIEW_USERNAME=you@example.com）。');
}

$user = $db->get("SELECT id FROM `user` WHERE `Username` = " . $db->quote($loginName) . " LIMIT 1");
if (empty($user)) {
	die('Incorrect Username: ' . htmlspecialchars($loginName));
}

userLogin($user->id);
die();

// ---------------------------------------------------------------------------
// 以下两个函数摘自仓库 web/login.php（die 之后的定义），供 userLogin() 使用。
// 仓库里改了它们的话，这里需要同步。
// ---------------------------------------------------------------------------
function userLogin($userId, $isAgree= null, $legalId=null, $userLegalLog = null, $o365url = "", $skipUserInfoUpdate = false) {
    global $db, $hasVerifiedSsoIdentity;
    mmcache_rm($_REQUEST['frm_username']);
    if (file_exists(BASE_DIR . "/../local/AntiXss")) {
        session_regenerate_id();
    }
    $_SESSION["currentuserid"] = $userId;
    $sql = "SELECT l.Code as Code FROM " . GLOBAL_DATABASE_NAME . ".user_default_language udl 
								JOIN `language` l ON udl.LanguageID = l.id
								WHERE udl.UserID =".$db->quote($_SESSION["currentuserid"])." and udl.SiteID = ".$db->quote(SITE_ID);
    $lan = $db->get($sql);
    if($lan){
        $_SESSION["currentlanguage"] = $lan->Code;
        setLanguage($_SESSION["currentlanguage"]);
    }

    //check user if his employee function role
    if(ifdef('ENABLE_LIST_OF_LOGGED_AGENTS')){
        checkFunctionalRole($userId);
    }



    unset($_SESSION['TK_IIDCUSTOMER']);
    $_SESSION['TK_IIDCUSTOMER']='local';

    $UserInformationServiceObj = UserInformationService::getInstance();
    if(!empty($isAgree) && !empty($legalId) && !empty($userLegalLog)){
        $UserInformationServiceObj->set($userId,$isAgree,$legalId);
        $userLegalLog->insertUserLegalAction($isAgree,$userId,"VIEW");
    }else{
        if ($skipUserInfoUpdate !== true) {
            $UserInformationServiceObj->set($userId);
        }
    }
    if (!empty($hasVerifiedSsoIdentity)) {
        $_SESSION['msalLogin']  = 1;
    }

    if($o365url){
        viewRedirect($o365url);
    }else{
        require_once(SYSTEM_DIR . "/libs/logic/SystemAdmin/User/Service/UserPasswordService.php");
        $userPasswordObj= new SystemAdmin\User\Service\UserPasswordService ($userId);
        $flg=$userPasswordObj->isPasswordExpired();
        if($flg){
            viewRedirect('/common/myaccount.php');
            exit;
        }      
        mmcache_put("salesInterceptor_NI_".$userId."_".session_id(),''); //DHC-A
        mmcache_put("salesInterceptor_MOD_".$userId."_".session_id(),'');
        if ($_REQUEST["donotlaunch"] || $_SERVER["REMOTE_ADDR"] == "192.168.1.24") {
            viewRedirect("/home.php");
        } else if (array_key_exists("url", $_REQUEST) && strlen($_REQUEST['url']) > 0 && $_REQUEST['url'] != '/') {
            if(preg_match("/^http(s)?:\\/\\/.+/",$_REQUEST['url'])){
                viewRedirect(LAUNCH_PAGE);
            }else{
                viewRedirect(html_entity_decode($_REQUEST['url']));
            }
        } else {
            viewRedirect(LAUNCH_PAGE);
        }
    }
}

function checkFunctionalRole($userId){
    global $db;
    //isCallCenterStaff
    $isCallCenterStaff = 0;
    $employeeSql = "SELECT e.id,e.UserID,e.FunctionalRoleID,f.IsCallCenterStaff FROM employee e LEFT JOIN functionalrole f on e.FunctionalRoleID = f.id  WHERE e.UserID = " . $db->quote($userId);
    $employeeInfo = $db->get($employeeSql);
    if($employeeInfo){
        if(isset($employeeInfo->FunctionalRoleID) && $employeeInfo->IsCallCenterStaff == 1){
            $isCallCenterStaff = 1;
        }
    }
    $_SESSION['isCallCenterStaff'] = $isCallCenterStaff;
}
