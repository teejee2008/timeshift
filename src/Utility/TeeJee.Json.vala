
/*
 * TeeJee.JsonHelper.vala
 *
 * Copyright 2016 Tony George <teejee2008@gmail.com>
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
			log_error ("Member not found in JSON object: " + member, false, true);
			return def_value;
		}
	}

	public double json_get_double(Json.Object jobj, string member, double def_value){
		var text = json_get_string(jobj, member, def_value.to_string());
		double double_value;
		if (double.try_parse(text, out double_value)){
			return double_value;
		}
		else{
			return def_value;
		}
	}

	public bool json_get_bool(Json.Object jobj, string member, bool def_value){
		if (jobj.has_member(member)){
			return bool.parse(jobj.get_string_member(member));
		}
		else{
			log_error ("Member not found in JSON object: " + member, false, true);
			return def_value;
		}
	}

	public int json_get_int(Json.Object jobj, string member, int def_value){
		if (jobj.has_member(member)){
			return int.parse(jobj.get_string_member(member));
		}
		else{
			log_error ("Member not found in JSON object: " + member, false, true);
			return def_value;
		}
	}
	
	public int64 json_get_int64(Json.Object jobj, string member, int64 def_value){
		if (jobj.has_member(member)){
			return int64.parse(jobj.get_string_member(member));
		}
		else{
			log_error ("Member not found in JSON object: " + member, false, true);
			return def_value;
		}
	}

	public Gee.ArrayList<string> json_get_array(
		Json.Object jobj,
		string member,
		Gee.ArrayList<string> def_value){
			
		if (jobj.has_member(member)){
			var jarray = jobj.get_array_member(member);
			var list = new Gee.ArrayList<string>();
			foreach(var node in jarray.get_elements()){
				list.add(node.get_string());
			}
			return list;
		}
		else{
			log_error ("Member not found in JSON object: " + member, false, true);
			return def_value;
		}
	}

}
