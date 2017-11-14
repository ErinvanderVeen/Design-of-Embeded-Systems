/*
 * generated by Xtext 2.12.0
 */
package gameOfLife.validation

import gameOfLife.rulesDSL.Game
import gameOfLife.rulesDSL.Rule
import gameOfLife.rulesDSL.RulesDSLPackage.Literals
import org.eclipse.xtext.validation.Check

/**
 * This class contains custom validation rules. 
 *
 * See https://www.eclipse.org/Xtext/documentation/303_runtime_concepts.html#validation
 */
class RulesDSLValidator extends AbstractRulesDSLValidator {
	 
	@Check
	def checkNumberOfNeighbours(Rule rule)
	{
		for(var i = 0; i < rule.neighbours.size(); i++)
		{
			if(rule.neighbours.get(i) >  8) 
				{warning("Neighbour number should not be greater than 8", Literals.RULE__NEIGHBOURS);}
			else if(rule.neighbours.get(i) < 0){
				warning("Neighbour number should not be negative", Literals.RULE__NEIGHBOURS);
			}
			 
		}
	}
	@Check
	def checkIdenticalCordinates(Game root)
	{
		var posList = root.positions
		for(var i=0; i < posList.size; i++){
			for(var j=i+1; j < posList.size; j++){
				
				if(posList.get(i).x.equals(posList.get(j).x) && posList.get(i).y.equals(posList.get(j).y))
				
				error("Identical coordinates are not allowed", Literals.GAME__POSITIONS, j);
				
			}
		}
	}
	@Check
	def checkIdenticalRules(Game root)
	{
		var ruleList = root.rules
		for(var i=0; i < ruleList.size; i++){
			for(var j=i+1; j < ruleList.size; j++){
				
				if(ruleList.get(i).initstate.equals(ruleList.get(j).initstate) && 
					ruleList.get(i).operator.equals(ruleList.get(j).operator) && 
					ruleList.get(i).neighbours.equals(ruleList.get(j).neighbours) && 
					ruleList.get(i).endstate.equals(ruleList.get(j).endstate))
				
				info("Identical rules are not allowed", Literals.GAME__RULES, j);
				
			}
		}
	}
}
