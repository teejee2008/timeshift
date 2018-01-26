
/*
 * ProcStats.vala
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

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.ProcessHelper;

public class ProcStats : GLib.Object {
		public double user = 0;
		public double nice = 0;
		public double system = 0;
		public double idle = 0;
		public double iowait = 0;

		public double user_delta = 0;
		public double nice_delta = 0;
		public double system_delta = 0;
		public double idle_delta = 0;
		public double iowait_delta = 0;

		public double usage_percent = 0;

		public static ProcStats stat_prev = null;

		public ProcStats(string line){
			string[] arr = line.split(" ");
			int col = 0;
			if (arr[col++] == "cpu"){
				if (arr[col].length == 0){ col++; };

				user = double.parse(arr[col++]);
				nice = double.parse(arr[col++]);
				system = double.parse(arr[col++]);
				idle = double.parse(arr[col++]);
				iowait = double.parse(arr[col++]);

				if (ProcStats.stat_prev != null){
					user_delta = user - ProcStats.stat_prev.user;
					nice_delta = nice - ProcStats.stat_prev.nice;
					system_delta = system - ProcStats.stat_prev.system;
					idle_delta = idle - ProcStats.stat_prev.idle;
					iowait_delta = iowait - ProcStats.stat_prev.iowait;

					usage_percent = (user_delta + nice_delta + system_delta) * 100 / (user_delta + nice_delta + system_delta + idle_delta);
				}
				else{
					usage_percent = 0;

				}

				ProcStats.stat_prev = this;
			}
		}
		
		//returns 0 when it is called first time
		public static double get_cpu_usage(){
			string txt = file_read("/proc/stat");
			foreach(string line in txt.split("\n")){
				string[] arr = line.split(" ");
				if (arr[0] == "cpu"){
					ProcStats stat = new ProcStats(line);
					return stat.usage_percent;
				}
			}
			return 0;
		}
	}

