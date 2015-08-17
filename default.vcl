vcl 4.0;

include "devicedetect.vcl";
import std;
import directors;

# set default backend if no server cluster specified

backend MainPHP {
    .host = "";
    .port = "";
	.first_byte_timeout = 120s;
}

#backend redishhvm {    .host = "";    .port = "";	.first_byte_timeout = 60s;
#		.probe = {		.url = "/Mainpage";		.timeout = 1m; 		.interval = 1m;		.window = 3;		.threshold = 2;		}	
#}

backend hhvm2 {
    .host = "";
    .port = "";
	.first_byte_timeout = 120s;
	#	.probe = {		.url = "/Mainpage";		.timeout = 1m; 		.interval = 1m;		.window = 3;		.threshold = 2;		}	
}



sub vcl_init {
    new MoegirlphpGroup = directors.round_robin();
    MoegirlphpGroup.add_backend(hhvm2);
}




# access control list for "purge": open to only localhost and other local nodes
acl purge {
	
}

 
# vcl_recv is called whenever a request is received 
sub vcl_recv {
	
#双层varnish设置……有不刷新的问题
#	if (req.restarts == 0) {
#		if (req.http.x-forwarded-for) {
#			set req.http.X-Forwarded-For = req.http.X-Forwarded-For;
#		} else {
#			set req.http.X-Forwarded-For = client.ip;
#		}
#	}

set req.http.X-Forwarded-For = client.ip;
	
	#手机跳转判断，先判定再重新bits.moegirl.org，顺序不能反
		#如果请求zh.moegirl.org
		if (req.http.host == "zh.moegirl.org"){
			if ( !(req.url ~ "toggle_view_desktop" ||req.http.Cookie ~ "stopMobileRedirect") ) {
				call devicedetect;
				
				if (req.http.X-UA-Device ~ "^mobile" || req.http.X-UA-device ~ "^tablet") {
					return(synth(751, "Moved Temporarily"));
				}
				
			}
		}
		
		#如果请求m.moegirl.org
		if (req.http.host ~ "m\.moegirl\.org") {
			set req.http.X-WAP = req.http.X-UA-Device;
		}

		
	#判断转发给哪台机子
		#非zh m bits.moegirl.org的请求丢回旧机处理
		if (! (req.http.host ~ "zh\.moegirl\.org" || req.http.host ~ "m\.moegirl\.org" || req.http.host ~ "bits\.moegirl\.org") ){  
			set req.backend_hint = MainPHP;
			
		#如果跟上传有关丢给旧机，special页面（上传图片，恢复被删除页面，Special:移动页面/File:），所有上传的文件，url里带upload和delete的（delete也有页面删除，鉴于删除少全转旧机大概没问题）
        }else if (req.url~ "Special:%E4%B8%8A%E4%BC%A0%E6%96%87%E4%BB%B6" || req.url~ "Special:%E6%81%A2%E5%A4%8D%E8%A2%AB%E5%88%A0%E9%A1%B5%E9%9D%A2" || req.url~ "Special:%E7%A7%BB%E5%8A%A8%E9%A1%B5%E9%9D%A2" || req.http.Content-Type ~ "multipart/form-data" || req.url ~ "upload" || req.url ~ "delete" ){ 
			set req.backend_hint = MainPHP;
		}else{
            set req.backend_hint = MoegirlphpGroup.backend();  #这几个繁忙站 zh bits m 要负载均衡
			
		# set req.backend_hint = MainPHP; #需要单机时启用这行
			

        }
		

	#把bits.moegirl.org/XX/load.php 重定向到 XX.moegirl.org/load.php
		if (req.http.host ~ "bits\.moegirl\.org" && req.url~ "^/\w+/load\.php") {
			set req.http.host = regsub(req.url, "^/(\w+)/.*", "\1") + ".moegirl.org";
			set req.url = regsub(req.url, "^/(\w+)/", "/");
		}
 
        # This uses the ACL action called "purge". Basically if a request to
        # PURGE the cache comes from anywhere other than localhost, ignore it.
        if (req.method == "PURGE") 
            {if (!client.ip ~ purge)
                {return(synth(405,"Not allowed."));}
            return(hash);}
 
        # Pass any requests that Varnish does not understand straight to the backend.
        if (req.method != "GET" && req.method != "HEAD" &&
            req.method != "PUT" && req.method != "POST" &&
            req.method != "TRACE" && req.method != "OPTIONS" &&
            req.method != "DELETE") 
            {return(pipe);}     /* Non-RFC2616 or CONNECT which is weird. */
 
        # Pass anything other than GET and HEAD directly.
        if (req.method != "GET" && req.method != "HEAD")
           {return(pass);}      /* We only deal with GET and HEAD by default */
		   
		
		#pass any request with "special:"
		if (req.url ~ "Special:" || req.url ~ "%E7%89%B9%E6%AE%8A:") {
			return(pass);
		}
		
		
		if (req.http.Cookie ~ "UserID") {
			if (!req.url ~ "^/load\.php") {
				return (pass);
			}
		} else {
				unset req.http.Cookie;
		}


        # Pass any requests with the "If-None-Match" header directly.
        if (req.http.If-None-Match)
           {return(pass);}
 
        # Force lookup if the request is a no-cache request from the client.
        if (req.http.Cache-Control ~ "no-cache")
           {ban(req.url);}
 
        # normalize Accept-Encoding to reduce vary
        if (req.http.Accept-Encoding) {
          if (req.http.User-Agent ~ "MSIE 6") {
            unset req.http.Accept-Encoding;
          } elsif (req.http.Accept-Encoding ~ "gzip") {
            set req.http.Accept-Encoding = "gzip";
          } elsif (req.http.Accept-Encoding ~ "deflate") {
            set req.http.Accept-Encoding = "deflate";
          } else {
            unset req.http.Accept-Encoding;
          }
        }
 
        return(hash);
}
 
sub vcl_pipe {
    # Note that only the first request to the backend will have
    # X-Forwarded-For set.  If you use X-Forwarded-For and want to
    # have it set for all requests, make sure to have:
    # set req.http.connection = "close";
 
	# This is otherwise not necessary if you do not do any request rewriting.
    set req.http.connection = "close";
}

# Called if the cache has a copy of the page.
sub vcl_hit {
        if (req.method == "PURGE") 
            {ban(req.url);
            return(synth(200,"Purged"));}
 
        if (!obj.ttl > 0s)
           {return(pass);}
}
 
# Called if the cache does not have a copy of the page.
sub vcl_miss {
        if (req.method == "PURGE") 
           {return(synth(200,"Not in cache"));}
}
 
# Called after a document has been successfully retrieved from the backend.
sub vcl_backend_response {

set beresp.http.X-Backend = beresp.backend.name;

#   让Vary 只包含 Accept-Encoding 和 Cookie, 防止产生过多的cache object
    if (beresp.http.Vary) {
		if (beresp.http.Vary ~ "Accept-Encoding") {
			set beresp.http.tempVary = "Accept-Encoding";
		}
		
		if (beresp.http.Vary ~ "Cookie") {
			if (beresp.http.tempVary) {
			  set beresp.http.tempVary = beresp.http.tempVary + ",Cookie";
			} else {
			  set beresp.http.tempVary = "Cookie";
			}
		}

		if (beresp.http.tempVary) {
			set beresp.http.Vary = beresp.http.tempVary;
			unset beresp.http.tempVary;
		} else {
			unset beresp.http.Vary;
		}
    }	
 
        # set minimum timeouts to auto-discard stored objects
#       set beresp.prefetch = -30s;
        set beresp.grace = 120s;
 

 
        if (!beresp.ttl > 0s) {
          set beresp.uncacheable = true;
          return (deliver);
        }
 
        if (beresp.http.Set-Cookie) {
          set beresp.uncacheable = true;
          return (deliver);
        }
 
 
        if (beresp.http.Authorization && !beresp.http.Cache-Control ~ "public") {
          set beresp.uncacheable = true;
          return (deliver);
        }

        return (deliver);
}

sub vcl_synth {
	if(resp.status == 751) {
		set resp.http.Location = "http://m.moegirl.org" + req.url;
		set resp.status = 302;
		return(deliver);
	}
}

sub vcl_backend_error {
set beresp.http.X-Backend = beresp.backend.name;
	
	# For 500 error 500错误用设置
#		if (beresp.status >= 500 && beresp.status <= 505) {
#			synthetic(std.fileread("/etc/varnish/50X.html"));
#			return(deliver);
#		}
#    return (deliver);
}
