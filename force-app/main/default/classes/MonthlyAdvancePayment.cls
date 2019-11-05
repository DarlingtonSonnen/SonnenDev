/**
 * Created by b.jarmolinski on 24/04/2018.
 */

public with sharing class MonthlyAdvancePayment {

    private Decimal yearlyConsumption;
    private Decimal freeElectricity;
    private Decimal price; // regular price
    private Decimal price2000;  // price above 2000 kWh

    public MonthlyAdvancePayment(Decimal yearlyConsumption, Decimal freeElectricity, Decimal price, Decimal price2000) {
        this.yearlyConsumption = yearlyConsumption;
        this.freeElectricity = freeElectricity;
        this.price = price;
        this.price2000 = price2000;
    }

    public Decimal calculate() {

        System.debug(yearlyConsumption);
        System.debug(freeElectricity);

        Decimal monthlyAdvPayment;
        if (yearlyConsumption <= freeElectricity) {
            monthlyAdvPayment = 0;
        } else if (yearlyConsumption <= (freeElectricity + 2000)) {
            monthlyAdvPayment = (Decimal) (((yearlyConsumption - freeElectricity)*price)/12).setScale(2);
        } else {
            monthlyAdvPayment = (Decimal)((2000*price + (yearlyConsumption - freeElectricity - 2000)*price2000)/12).setScale(2);
        }

        return monthlyAdvPayment;
    }
    public static Decimal calculate(Decimal yearlyConsumption, Decimal freeElectricity, Decimal price, Decimal price2000) {
        
        System.debug(yearlyConsumption);
        System.debug(freeElectricity);
        System.debug(price);
        System.debug(price2000);

        Decimal monthlyAdvPayment;
        if (yearlyConsumption <= freeElectricity) {
            monthlyAdvPayment = 0;
        } else if (yearlyConsumption <= (freeElectricity + 2000)) {
            monthlyAdvPayment = (Decimal) (((yearlyConsumption - freeElectricity)*price)/12).setScale(2);
        } else {
            monthlyAdvPayment = (Decimal)((2000*price + (yearlyConsumption - freeElectricity - 2000)*price2000)/12).setScale(2);
        }

        return monthlyAdvPayment;
    }
}