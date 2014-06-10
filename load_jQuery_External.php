$wgHooks['SkinAfterBottomScripts'][] = 'fnRemoveAnnoingJS';

//去除mediawiki默认jQuery
function fnRemoveAnnoingJS($skin, &$text) {
 
  $n = "\n";
  $t = "\t";
  $text = $text.'<script language="JavaScript" type="text/javascript">
/*<![CDATA[*/
 
jQuery.noConflict(true);
 
/*]]>*/
</script>'; 
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
