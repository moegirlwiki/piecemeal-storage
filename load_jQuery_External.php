$wgHooks['SkinAfterBottomScripts'][] = 'fnRemoveAnnoingJS';

//使得不需要jquery的代码不用jquery
function fnRemoveAnnoingJS($skin, &$text) {
 
  $n = "\n";
  $t = "\t";
  $text = $text.'<script language="JavaScript" type="text/javascript">
/*<![CDATA[*/
 
jQuery.noConflict(true);
 
/*]]>*/
</script>'.
  $n.
  '<script type="text/javascript" src="/fileYouWantToWorkWithoutStupidBuggy.1.4.2.js"></script>';
 
  return true;
 
}
 
//添加外部JS
$wgHooks['ParserBeforeTidy'][] = 'wgAddJquery';
 
function wgAddJquery(&$parser, &$text) {
 
  global $addJqueryScripts;
  if ($addJqueryScripts === true) return true;
 
  $parser->mOutput->addHeadItem(
    '<script language="JavaScript" src="https://ajax.googleapis.com/ajax/libs/jquery/1/jquery.min.js" type="text/javascript"></script>'
  );
 
  $addJqueryScripts = true;
 
  return true;
 
}
