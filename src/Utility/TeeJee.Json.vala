
/*
 * TeeJee.JsonHelper.vala
 *
 * Copyright 2012-2018 Tony George <teejeetech@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 *
 *
 */
 
using Json;

namespace TeeJee.JsonHelper{

	using TeeJee.Logging;

	/* Convenience functions for reading and writing JSON files */

	public string json_get_string(Json.Object jobj, string member, string def_value){
		if (jobj.has_member(member)){
			return jobj.get_string_member(member);
		}
		else{
			log_debug ("Member not found in JSON object: " + member);
			return def_value;
		}
	}

	public bool json_get_bool(Json.Object jobj, string member, bool def_value){
		if (jobj.has_member(member)){
			return bool.parse(jobj.get_string_member(member));
		}
		else{
			log_debug ("Member not found in JSON object: " + member);
			return def_value;
		}
	}

	public int json_get_int(Json.Object jobj, string member, int def_value){
		if (jobj.has_member(member)){
			return int.parse(jobj.get_string_member(member));
		}
		else{
			log_debug ("Member not found in JSON object: " + member);
			return def_value;
		}
	}
	
	public uint64 json_get_uint64(Json.Object jobj, string member, uint64 def_value){
		if (jobj.has_member(member)){
			return uint64.parse(jobj.get_string_member(member));
		}
		else{
			log_debug ("Member not found in JSON object: " + member);
			return def_value;
		}
	}
}
