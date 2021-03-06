package org.vanderveen.ev3rt.generator

import org.vanderveen.ev3rt.behaviourDSL.Mission
import org.vanderveen.ev3rt.behaviourDSL.Condition
import org.vanderveen.ev3rt.behaviourDSL.Behaviour
import org.vanderveen.ev3rt.behaviourDSL.Operator
import org.vanderveen.ev3rt.behaviourDSL.Sensor
import org.vanderveen.ev3rt.behaviourDSL.Value
import org.vanderveen.ev3rt.behaviourDSL.PressedState
import org.vanderveen.ev3rt.behaviourDSL.Color
import org.vanderveen.ev3rt.behaviourDSL.Distance
import org.vanderveen.ev3rt.behaviourDSL.TouchValue
import org.vanderveen.ev3rt.behaviourDSL.ColorValue
import org.vanderveen.ev3rt.behaviourDSL.Move
import org.vanderveen.ev3rt.behaviourDSL.Turn
import org.vanderveen.ev3rt.behaviourDSL.Direction
import org.vanderveen.ev3rt.behaviourDSL.Variable
import org.vanderveen.ev3rt.behaviourDSL.TruthValue
import org.vanderveen.ev3rt.behaviourDSL.Control
import org.vanderveen.ev3rt.behaviourDSL.Complete
import org.vanderveen.ev3rt.behaviourDSL.Arm
import org.vanderveen.ev3rt.behaviourDSL.Stop

class CppGenerator {
	def static toCpp(Mission mission)'''
		#include "app.hpp"

		#include <iterator>
		#include <list>
		
		int32_t FONT_WIDTH, FONT_HEIGHT, NLINES;

		int line = 0;
		
		void cycle_print(char* message) {
			int printLine = ++line % NLINES;
			if (line >= NLINES)
				ev3_lcd_clear_line_range(printLine, printLine + 1);
			ev3_print(printLine, message);
		}

		struct SharedMemory {
			«FOR Variable variable : mission.variables»
				«fromVariable(variable)»
			«ENDFOR»
		};

		struct SensorData {
			// MASTER
			colorid_t color_left;
			int16_t ultra_back;
			int16_t gyro_angle;
			int16_t gyro_rate;
			colorid_t color_right;

			// SLAVE
			int touch_left;
			colorid_t color_center;
			int16_t ultra_front;
			int touch_right;
		};

		// Should not be called "Sensors"
		struct Sensors {
			sensor_port_t COLORL_P = EV3_PORT_1;
			sensor_port_t ULTRAB_P = EV3_PORT_2;
			sensor_port_t GYRO_P = EV3_PORT_3;
			sensor_port_t COLORR_P = EV3_PORT_4;

			motor_port_t LEFT_P = EV3_PORT_A;

			motor_port_t ARM_P = EV3_PORT_C;
			motor_port_t RIGHT_P = EV3_PORT_D;
		};

		SharedMemory shared_memory;
		SensorData sensor_data;
		Sensors sensors;
		
		int16_t gyro_angle = 0;

		uint8_t slave_address[6] = { 0x00, 0x17, 0xE9, 0xB4, 0xCB, 0xF3 };
		const char* pin = "0000";
		static FILE *bt_con;
		
		
		void stop_motors() {
			ev3_motor_stop(sensors.LEFT_P, true);
			ev3_motor_stop(sensors.RIGHT_P, true);
		}

		class RobotAction {
			public:
				enum Control { SKIP, BLOCK, PASS };
				virtual Control takeControl() = 0;
				virtual void perform() = 0;
				virtual void printName() = 0;
				
		};

		RobotAction* current_action;
		RobotAction::Control current_control;

		«FOR behavior : mission.behaviours»
				«fromBehavior(behavior)»;
		«ENDFOR»

		class Arbitrator {
			public:
				Arbitrator() {}

				void start() {
					bool running = true;

					RobotAction::Control control;

					while(running) {

						// Read current values from sensors
						// Actions that need access to the data, whould have been passed
						// a reference to it in their constructor
						update_sensor_data();

						assess_actions(control);

						// Sleep to allow execution of behavior
						sleep(50);
						

					}
					return;
				}

				void apply(RobotAction* mode) {
					actions.push_back(mode);
					return;
				}

			private:
				std::list<RobotAction*> actions;
				void restart_behavior_task() {
					// Kill and restart task
					ter_tsk(BEHAVIOR_TASK);
					act_tsk(BEHAVIOR_TASK);
				}

			void assess_actions(RobotAction::Control& control) {
				cycle_print((char*)"i_assess_actions");
				
				for (RobotAction* action : actions) {
					control = action->takeControl();
					if (action == current_action && current_control == RobotAction::BLOCK) {
						// The current action has the highest priority
						return;
					}
	
					switch (control) {
						case RobotAction::SKIP:
							// Do nothing
							break;
						case RobotAction::BLOCK:
							//action->printName();
							if (action != current_action) {
								current_action = action;
								restart_behavior_task();
								current_control = RobotAction::BLOCK;
							}
							return;
						case RobotAction::PASS:
							if (action != current_action) {
								current_action = action;
								restart_behavior_task();
								current_control = RobotAction::PASS;
							}
							return;
					}
				}
			}

				void update_sensor_data() {
					//cycle_print((char*)"i_update_sensor_data");
					sensor_data.color_left = ev3_color_sensor_get_color(sensors.COLORL_P);
					sensor_data.ultra_back = ev3_ultrasonic_sensor_get_distance(sensors.ULTRAB_P);
					sensor_data.gyro_angle = ev3_gyro_sensor_get_angle(sensors.GYRO_P);
					sensor_data.gyro_rate = ev3_gyro_sensor_get_rate(sensors.GYRO_P);
					sensor_data.color_right = ev3_color_sensor_get_color(sensors.COLORR_P);
					//cycle_print((char*)"o_update_sensor_data");
				}
		};

		void set_font(lcdfont_t font) {
			ev3_lcd_set_font(font);
			ev3_font_get_size(font, &FONT_WIDTH, &FONT_HEIGHT);
			NLINES = EV3_LCD_HEIGHT / FONT_HEIGHT;
		}

		bool_t isConnected() {
			T_SERIAL_RPOR rpor;
			ER ercd = serial_ref_por(SIO_PORT_SPP_MASTER_TEST, &rpor);
			return ercd == E_OK;
		}

		void btConnect() {
			while(true) {
				bt_con = fdopen(SIO_PORT_SPP_MASTER_TEST_FILENO, "a+");
				//open file for update(read & write), append mode
				if (bt_con != NULL) {
					setbuf(bt_con, NULL);
					while (!isConnected()) {
						cycle_print((char*)"Connecting...");
						spp_master_test_connect(slave_address, pin);
						sleep(1000);
					}
					break;
				}
				sleep(1000);
			}
			act_tsk(BLUETOOTH_TASK);
			cycle_print((char*)"Connected.");
			cycle_print((char*)"Master");
		}
		

		void init() {
			btConnect();

			set_font(EV3_FONT_SMALL);

			//	Sensor init
			ev3_sensor_config(sensors.COLORL_P, COLOR_SENSOR);
			ev3_sensor_config(sensors.ULTRAB_P, ULTRASONIC_SENSOR);
			ev3_sensor_config(sensors.GYRO_P, GYRO_SENSOR);
			ev3_sensor_config(sensors.COLORR_P, COLOR_SENSOR);

			//	Motor init
			ev3_motor_config(sensors.LEFT_P, LARGE_MOTOR);

			ev3_motor_config(sensors.ARM_P, MEDIUM_MOTOR);
			ev3_motor_config(sensors.RIGHT_P, LARGE_MOTOR);
		}
		
		void arbitrator_task(intptr_t unused) {
			init();
		
			Arbitrator* arbitrator = new Arbitrator;
			cycle_print((char*)"Arbitrator Created");
		
			«FOR Behaviour behaviour : mission.behaviours»
				arbitrator->apply(new «behaviour.name»());
			«ENDFOR»
		
			cycle_print((char*)"Behaviors Created");
		
			arbitrator->start();
		}
		
		void behavior_task(intptr_t unused) {
			cycle_print((char*)"s_behavior_task");
			current_action->printName();
			current_action->perform();
		}
		
		void bluetooth_task(intptr_t unused) {
			static char c;
			while ((c = fgetc(bt_con))) {
				//cycle_print(&c);
				switch(c) {
					case 'l':
						fread(&sensor_data.touch_left, sizeof(sensor_data.touch_left), 1, bt_con);
						break;
					case 'r':
						fread(&sensor_data.touch_right, sizeof(sensor_data.touch_right), 1, bt_con);
						break;
					case 'c':
						fread(&sensor_data.color_center, sizeof(sensor_data.color_center), 1, bt_con);
						break;
					case 'u':
						fread(&sensor_data.ultra_front, sizeof(sensor_data.ultra_front), 1, bt_con);
						break;
				}
			}
		}
		

	'''
	
	def static fromVariable(Variable variable)'''
	bool «variable.name» = «IF variable.value == TruthValue::TRUE»true«ENDIF»«IF variable.value == TruthValue::FALSE»false«ENDIF»;
	'''
	
	def static fromBehavior(Behaviour behaviour)'''
		class «behaviour.name» : public RobotAction {
					public:
						Control takeControl() {
							«IF !behaviour.conditions.isEmpty»
							if(«FOR condition : behaviour.conditions SEPARATOR " && "»«fromCondition(condition)»«ENDFOR»)
							«ENDIF»
								return «fromControl(behaviour.control)»;
							return SKIP;
						}
						
						void perform() {
							«FOR action : behaviour.actions»
								«fromAction(action)»
							«ENDFOR»
							current_action = NULL;
							wup_tsk(ARBITRATOR_TASK);
						}
		
						void printName() {
							cycle_print((char*)"«behaviour.name»");
						}
				}'''
	
	def static fromControl(Control control) {
		switch(control) {
			case Control::SKIP: return '''SKIP'''
			case Control::BLOCK: return '''BLOCK'''
			case Control::PASS: return '''PASS'''
			default: throw new UnsupportedOperationException("Unsupported Control Word")
		}		
	}
	
	def static dispatch fromAction(Move move)'''
		ev3_motor_set_power(sensors.LEFT_P, «IF move.direction == Direction::BACKWARD»-«ENDIF»20);
		ev3_motor_set_power(sensors.RIGHT_P, «IF move.direction == Direction::BACKWARD»-«ENDIF»20);
		sleep(90 * «move.distance.cm»);
	'''
	
	def static dispatch fromAction(Stop stop)'''
		stop_motors();
	'''
	
	def static dispatch fromAction(Turn turn)'''
		ev3_motor_set_power(sensors.LEFT_P, «IF turn.direction == Direction::LEFT»-«ENDIF»10);
		ev3_motor_set_power(sensors.RIGHT_P, «IF turn.direction == Direction::RIGHT»-«ENDIF»10);
		sleep(6000 * «turn.rotation.degrees» / 360);
	'''
	
	def static dispatch fromAction(Variable variable)'''
		shared_memory.«variable.name» = «IF variable.value == TruthValue::TRUE»true«ENDIF»«IF variable.value == TruthValue::FALSE»false«ENDIF»;
	'''
	
	def static dispatch fromAction(Complete complete)'''
		ev3_motor_stop(sensors.LEFT_P, true);
		ev3_motor_stop(sensors.RIGHT_P, true);
		exit(«complete.returncode»);
	'''
	
	def static dispatch fromAction(Arm arm)'''
		ev3_motor_rotate(sensors.ARM_P, «IF arm.direction == Direction::DOWN»-«ENDIF»90, 5, true);
	'''
	
	def static dispatch fromCondition(Condition condition)'''
		«fromSensor(condition.sensor)» «fromOperator(condition.operator)» «fromValue(condition.value)»
	'''
	
	def static dispatch fromCondition(Variable variable)'''
		shared_memory.«variable.name» == «variable.value»
	'''
	
	def static fromSensor(Sensor sensor) {
		switch(sensor) {
			case Sensor::TOUCH_L: return '''sensor_data.touch_left'''
			case Sensor::TOUCH_R: return '''sensor_data.touch_right'''
			case Sensor::COLOR_L: return '''sensor_data.color_left'''
			case Sensor::COLOR_C: return '''sensor_data.color_center'''
			case Sensor::COLOR_R: return '''sensor_data.color_right'''	
			case Sensor::SONIC_F: return '''sensor_data.ultra_front'''
			case Sensor::SONIC_B: return '''sensor_data.ultra_back'''
			default: throw new UnsupportedOperationException("Unsupported Sensor")
		}		
	}
	
	def static fromOperator(Operator operator) {
		switch(operator) {
			case Operator::EQ: return '''=='''
			case Operator::NEQ: return '''!='''
			case Operator::GT: return '''>'''
			case Operator::LT: return '''<'''
			case Operator::GEQ: return '''>='''
			case Operator::LEQ: return '''<='''
			default: throw new UnsupportedOperationException("Unsupported Operator")
		}
	}
	
	def static dispatch fromValue(TouchValue state) {
		switch(state.pressed) {
			case PressedState::PRESSED:
				return '''1'''
			case PressedState::UNPRESSED:
				return '''0'''
			default:
				throw new UnsupportedOperationException("Unsupported Pressed State")
		}
	}
	
	def static dispatch fromValue(ColorValue color) {
		switch(color.color) {
			case BLACK:
				return '''COLOR_BLACK'''
			case BLUE:
				return '''COLOR_BLUE'''
			case RED:
				return '''COLOR_RED'''
			case WHITE:
				return '''COLOR_WHITE'''
			case YELLOW:
				return '''COLOR_YELLOW'''
			case GREEN:
				return '''COLOR_GREEN'''
			default:
				throw new UnsupportedOperationException("Unsupported Color")
			
		}
	}
	
	def static dispatch fromValue(Distance dist)'''
		«dist.cm»
	'''
	
}
