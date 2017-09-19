//
//  BudgetModel.swift
//  Emacity
//
//  Created by Davis Barber on 21/8/17.
//  Copyright © 2017 Davis Barber. All rights reserved.
//

import Foundation
import CoreData

class BudgetModel {
    
    var currentPayCheck: PayCheck?
    var endDate: Date? {
        if let startDate = currentPayCheck?.date as Date? {
            return Date(timeInterval: getPayInterval(), since: startDate)
        } else {
            return nil
        }
    }
    var budgetChanged = false
    var payCheckIsCurrent = false
    var recentTransactions = [Transaction]()
    var goals = [Goal]()
    
    var payPeriodDays: Double {
        var days = 0.0
        switch (UserDefaults.standard.value(forKey: "payPeriod") as? String)! {
        case "Weekly":
            days = 7
        case "Bi-Monthly":
            days = 14
        case "Monthly":
            days = 28
        default:
            break
        }
        return days
    }
    
    func isPayCheckCurrent() -> Bool{
        let date = Date()
        // Fetch most recent pay check
        let fetchRequest: NSFetchRequest<PayCheck> = PayCheck.fetchRequest()
        // Sort by date and only fetch most recent paycheck
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchRequest.fetchLimit = 1
        
        do {
            let searchResults = try Database.getContext().fetch(fetchRequest)
            print(searchResults.count)
            // If there is no paycheck
            if searchResults.count == 0 {
                payCheckIsCurrent = false
            } else {
                currentPayCheck = searchResults[0]
                // Check if paycheck is current
                if date > endDate! {
                    // Paycheck isn't current so return false
                    payCheckIsCurrent = false
                    
                }
                // Paycheck is valid so return true
                payCheckIsCurrent = true
                
            }
            
        } catch  {
            print("Error: \(error)")
        }
        
        return payCheckIsCurrent
    }
    
    // Returns remaining budget to display on screen
    // **** Need to split this up into different methods ****
    // **** Should only check goals cost when adding paycheck, adding or removing goals
    //Get separate values for cost of goals, debits, and credits
    func getRemainingBudgetAndProgress() -> (Double, Double) {
        
        if !payCheckIsCurrent {
            return (0,0)
        }
        
        // Calculate budgetRemaining
        var remainingMoney = getSpendingMoney()
        
        // ***** Need to add Credits for current pay period to totalValue here *****
        let totalRemainingBudget = remainingMoney
        // Update Transactions
        getRecentTransactions()
        // Keep track of total spending this pay period
        var moneySpent = 0.0
        for debit in recentTransactions {
            remainingMoney -= debit.amount
            moneySpent += debit.amount
        }
        
        
        // Calculate Progress
        let progressPercentage = moneySpent / totalRemainingBudget
        print(totalRemainingBudget)
        print(progressPercentage)
        return (remainingMoney, progressPercentage)
        
    }
    
    
    
    func getTimeRemaining() -> DateComponents {
        var calendar = Calendar.current
        calendar.timeZone = NSTimeZone.local
        let date = Date()
        
        if let payDay = endDate {
            // returns positive or neg
            return calendar.dateComponents([.day, .hour, .minute], from: date, to: payDay)
            
        } else {
            // return all 0s
            return calendar.dateComponents([.day, .hour, .minute], from: date)
        }
        
    }
    
    // Fetch all transactions for current Pay Period
    private func getRecentTransactions() {
        let fetchRequest: NSFetchRequest<Transaction> = Transaction.fetchRequest()
       // let newEndDate: NSDate = endDate! as NSDate
        
        let predicate = NSPredicate(format: "date > %@", (currentPayCheck?.date)!)
        fetchRequest.predicate = predicate
        do {
            let searchResults = try Database.getContext().fetch(fetchRequest)
            print(searchResults.count)
            recentTransactions = searchResults
            
        } catch  {
            print("Error: \(error)")
        }
    }
    
    // Get total spending money after goals and transactions subtracted
    private func getSpendingMoney() -> Double {
        getGoals()
        var total = (currentPayCheck?.amount)!
        // Subtract cost of each goal from total spending money
        for goal in goals {
            let goalCost = getGoalCostForPayPeriod(for: goal)
            total -= goalCost
        }
        return total
    }
    
    private func getGoalCostForPayPeriod(for goal: Goal) -> Double {
        var calendar = Calendar.current
        calendar.timeZone = NSTimeZone.local
        //start and completion of goal
        let completionDate = (goal.completionDate)! as Date
        let startDate = (goal.startDate)! as Date
        
        let totalGoalDays = calendar.dateComponents([.day], from: startDate, to: completionDate)
        // Cost per day for goal
        let dailyAmount = goal.totalAmount / Double(totalGoalDays.day!)
        
        let payCheckStartDate = (currentPayCheck?.date)! as Date
        // Check whether goal's start and end day are inside current payperiod
        if startDate <= payCheckStartDate && completionDate >= endDate! {
            // goal starts and ends outside payPeriod
            return dailyAmount*payPeriodDays
        } else if startDate <= payCheckStartDate && completionDate < endDate! {
            // goal ends during pay period
            let days = calendar.dateComponents([.day], from: payCheckStartDate, to: completionDate).day!
            return dailyAmount*Double(days)
        } else if startDate > payCheckStartDate && completionDate >= endDate! {
            // goal starts during pay period
            let days = calendar.dateComponents([.day], from: startDate, to: endDate!).day!
            return dailyAmount*Double(days)
        } else {
            // goal starts and ends inside pay period
            let days = calendar.dateComponents([.day], from: startDate, to: completionDate).day!
            return dailyAmount*Double(days)
        }
        
        
    }
    
    // Fetch Goals from Database
    private func getGoals() {
        let fetchRequest: NSFetchRequest<Goal> = Goal.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isCompleted == %@", false as CVarArg)
        
        do {
            let searchResults = try Database.getContext().fetch(fetchRequest)
            print(searchResults.count)
            goals = searchResults
            
        } catch  {
            print("Error: \(error)")
        }
        
    }
    
    // Creates a time interval based on chosen payPeriod in settings
    private func getPayInterval() -> TimeInterval {
        
        return TimeInterval(payPeriodDays*24*60*60)
    }
    
    

    
}
